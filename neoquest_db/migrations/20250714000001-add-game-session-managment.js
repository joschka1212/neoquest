/**
 * Migration: Add Game Session Management System (PostgreSQL Optimized)
 * File: migrations/20250713180001-add-game-session-management.js
 * 
 * PostgreSQL-specific considerations:
 * - Proper IF NOT EXISTS handling
 * - Schema-aware operations
 * - Constraint naming conventions
 * - Transaction safety
 * - Default value handling
 * 
 *   Fixed version removing problematic RAISE NOTICE statements
 */

'use strict';

var dbm;
var type;
var seed;

exports.setup = function(options, seedLink) {
  dbm = options.dbmigrate;
  type = dbm.dataType;
  seed = seedLink;
};

exports.up = function(db) {
  console.log('🚀 Adding game session management system (FIXED)...');
  
  return db.runSql(`
    -- Ensure we're working in the correct schema
    SET search_path TO neoquest, public;
    
    -- ===============================================
    -- SESSION STATUS ENUM (Fixed)
    -- ===============================================
    
    -- Check if enum already exists before creating
    DO $$ 
    BEGIN
      -- Only create if it doesn't exist
      IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'session_status_enum' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'neoquest')) THEN
        CREATE TYPE neoquest.session_status_enum AS ENUM (
          'registration',   -- Players can register and mark ready
          'waiting',        -- Waiting for admin to start
          'countdown',      -- Countdown is active  
          'started',        -- Game is running
          'paused',         -- Game temporarily paused
          'finished'        -- Game session ended
        );
      END IF;
    END $$;
    
    -- ===============================================
    -- COORDINATED SESSIONS TABLE
    -- ===============================================
    
    -- Create table only if it doesn't exist
    CREATE TABLE IF NOT EXISTS neoquest.coordinated_sessions (
      id SERIAL PRIMARY KEY,
      session_name VARCHAR(255) NOT NULL DEFAULT 'Main Session',
      status neoquest.session_status_enum NOT NULL DEFAULT 'registration',
      countdown_seconds INTEGER NOT NULL DEFAULT 0 CHECK (countdown_seconds >= 0 AND countdown_seconds <= 3600),
      countdown_start_time TIMESTAMP WITH TIME ZONE,
      actual_start_time TIMESTAMP WITH TIME ZONE,
      end_time TIMESTAMP WITH TIME ZONE,
      admin_message TEXT DEFAULT 'Players can register and mark themselves ready',
      admin_user VARCHAR(100) DEFAULT 'system',
      session_config JSONB NOT NULL DEFAULT '{}',
      total_expected_players INTEGER NOT NULL DEFAULT 0 CHECK (total_expected_players >= 0),
      created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      
      -- Constraints
      CONSTRAINT coordinated_sessions_countdown_logic 
        CHECK (
          (status != 'countdown') OR 
          (status = 'countdown' AND countdown_seconds > 0 AND countdown_start_time IS NOT NULL)
        ),
      CONSTRAINT coordinated_sessions_time_logic
        CHECK (actual_start_time IS NULL OR actual_start_time >= created_at),
      CONSTRAINT coordinated_sessions_end_time_logic
        CHECK (end_time IS NULL OR (actual_start_time IS NOT NULL AND end_time >= actual_start_time))
    );
    
  `).then(function() {
    console.log('  ✅ Created session_status_enum and coordinated_sessions table');
    
    return db.runSql(`
      SET search_path TO neoquest, public;
      
      -- Add table and column comments
      COMMENT ON TABLE neoquest.coordinated_sessions IS 'Manages coordinated multiplayer game sessions with server GO signals';
      COMMENT ON COLUMN neoquest.coordinated_sessions.status IS 'Current session status with enum constraint';
      COMMENT ON COLUMN neoquest.coordinated_sessions.countdown_seconds IS 'Duration of countdown in seconds (0-3600, validated by check constraint)';
      COMMENT ON COLUMN neoquest.coordinated_sessions.countdown_start_time IS 'Timestamp when countdown started (WITH TIME ZONE for accuracy)';
      COMMENT ON COLUMN neoquest.coordinated_sessions.actual_start_time IS 'Timestamp when game actually started (WITH TIME ZONE)';
      COMMENT ON COLUMN neoquest.coordinated_sessions.admin_message IS 'Custom message from admin shown to players (TEXT type for unlimited length)';
      COMMENT ON COLUMN neoquest.coordinated_sessions.session_config IS 'Additional session configuration stored as JSONB';
      COMMENT ON COLUMN neoquest.coordinated_sessions.total_expected_players IS 'Expected number of players (for capacity planning)';
      
    `);
  }).then(function() {
    console.log('  ✅ Added table comments');
    
    return db.runSql(`
      SET search_path TO neoquest, public;
      
      -- ===============================================
      -- EXTEND PLAYERS TABLE
      -- ===============================================
      
      -- Add columns only if they don't exist
      DO $$
      BEGIN
        -- Check and add session_ready column
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'neoquest' AND table_name = 'players' AND column_name = 'session_ready') THEN
          ALTER TABLE neoquest.players ADD COLUMN session_ready BOOLEAN NOT NULL DEFAULT FALSE;
        END IF;
        
        -- Check and add ready_timestamp column
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'neoquest' AND table_name = 'players' AND column_name = 'ready_timestamp') THEN
          ALTER TABLE neoquest.players ADD COLUMN ready_timestamp TIMESTAMP WITH TIME ZONE;
        END IF;
        
        -- Check and add session_joined_at column
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'neoquest' AND table_name = 'players' AND column_name = 'session_joined_at') THEN
          ALTER TABLE neoquest.players ADD COLUMN session_joined_at TIMESTAMP WITH TIME ZONE;
        END IF;
        
        -- Check and add ready_device_info column
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'neoquest' AND table_name = 'players' AND column_name = 'ready_device_info') THEN
          ALTER TABLE neoquest.players ADD COLUMN ready_device_info JSONB NOT NULL DEFAULT '{}';
        END IF;
      END $$;
      
    `);
  }).then(function() {
    console.log('  ✅ Extended players table with session fields');
    
    return db.runSql(`
      SET search_path TO neoquest, public;
      
      -- Add constraint to players table
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema = 'neoquest' AND table_name = 'players' AND constraint_name = 'players_ready_timestamp_logic') THEN
          ALTER TABLE neoquest.players 
          ADD CONSTRAINT players_ready_timestamp_logic 
          CHECK ((session_ready = FALSE) OR (session_ready = TRUE AND ready_timestamp IS NOT NULL));
        END IF;
      END $$;
      
      -- Add comments for new player columns
      COMMENT ON COLUMN neoquest.players.session_ready IS 'Whether player has marked themselves ready for coordinated start (NOT NULL with default)';
      COMMENT ON COLUMN neoquest.players.ready_timestamp IS 'When player marked themselves ready (WITH TIME ZONE)';
      COMMENT ON COLUMN neoquest.players.session_joined_at IS 'When player first joined the session (WITH TIME ZONE)';
      COMMENT ON COLUMN neoquest.players.ready_device_info IS 'Device/app info when player marked ready (JSONB NOT NULL with default)';
      
    `);
  }).then(function() {
    console.log('  ✅ Added player table constraints and comments');
    
    return db.runSql(`
      SET search_path TO neoquest, public;
      
      -- ===============================================
      -- SESSION PARTICIPANTS TABLE
      -- ===============================================
      
      CREATE TABLE IF NOT EXISTS neoquest.session_participants (
        id SERIAL PRIMARY KEY,
        session_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        marked_ready_at TIMESTAMP WITH TIME ZONE,
        started_game_at TIMESTAMP WITH TIME ZONE,
        completed_game_at TIMESTAMP WITH TIME ZONE,
        final_status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (final_status IN ('active', 'completed', 'abandoned', 'disqualified')),
        participant_notes TEXT,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        
        -- Constraints with proper naming
        CONSTRAINT fk_session_participants_session_id 
          FOREIGN KEY (session_id) REFERENCES neoquest.coordinated_sessions(id) ON DELETE CASCADE,
        CONSTRAINT fk_session_participants_player_id 
          FOREIGN KEY (player_id) REFERENCES neoquest.players(id) ON DELETE CASCADE,
        CONSTRAINT uk_session_participants_session_player 
          UNIQUE(session_id, player_id),
        CONSTRAINT session_participants_timestamp_logic
          CHECK (
            marked_ready_at IS NULL OR marked_ready_at >= joined_at
          ),
        CONSTRAINT session_participants_game_timestamp_logic
          CHECK (
            started_game_at IS NULL OR 
            (marked_ready_at IS NOT NULL AND started_game_at >= marked_ready_at)
          ),
        CONSTRAINT session_participants_completion_logic
          CHECK (
            completed_game_at IS NULL OR 
            (started_game_at IS NOT NULL AND completed_game_at >= started_game_at)
          )
      );
      
      COMMENT ON TABLE neoquest.session_participants IS 'Tracks player participation in coordinated sessions with full audit trail';
      COMMENT ON COLUMN neoquest.session_participants.final_status IS 'Final participation status with CHECK constraint validation';
      
    `);
  }).then(function() {
    console.log('  ✅ Created session_participants table');
    
    return db.runSql(`
      SET search_path TO neoquest, public;
      
      -- ===============================================
      -- SESSION EVENTS LOG
      -- ===============================================
      
      CREATE TABLE IF NOT EXISTS neoquest.session_events (
        id SERIAL PRIMARY KEY,
        session_id INTEGER NOT NULL,
        event_type VARCHAR(50) NOT NULL CHECK (event_type IN (
          'session_created', 'status_changed', 'countdown_started', 'game_started', 
          'game_paused', 'game_resumed', 'game_finished', 'player_joined', 
          'player_ready', 'player_started', 'player_completed', 'admin_action'
        )),
        event_data JSONB NOT NULL DEFAULT '{}',
        triggered_by VARCHAR(100) NOT NULL DEFAULT 'system',
        player_id INTEGER, -- Optional: which player triggered the event
        timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        
        -- Foreign key constraints with proper naming
        CONSTRAINT fk_session_events_session_id 
          FOREIGN KEY (session_id) REFERENCES neoquest.coordinated_sessions(id) ON DELETE CASCADE,
        CONSTRAINT fk_session_events_player_id 
          FOREIGN KEY (player_id) REFERENCES neoquest.players(id) ON DELETE SET NULL
      );
      
      COMMENT ON TABLE neoquest.session_events IS 'Event log for session management with structured event types';
      COMMENT ON COLUMN neoquest.session_events.event_type IS 'Predefined event types validated by CHECK constraint';
      COMMENT ON COLUMN neoquest.session_events.triggered_by IS 'Who/what triggered the event: admin username, system, or player identifier';
      
    `);
  }).then(function() {
    console.log('  ✅ Created session_events table');
    
    return db.runSql(`
      SET search_path TO neoquest, public;
      
      -- ===============================================
      -- INDEXES FOR PERFORMANCE
      -- ===============================================
      
      -- Coordinated sessions indexes
      CREATE INDEX IF NOT EXISTS idx_coordinated_sessions_status 
      ON neoquest.coordinated_sessions(status) 
      WHERE status IN ('registration', 'waiting', 'countdown', 'started');
      
      CREATE INDEX IF NOT EXISTS idx_coordinated_sessions_active_countdown 
      ON neoquest.coordinated_sessions(status, countdown_start_time, countdown_seconds) 
      WHERE status = 'countdown';
      
      CREATE INDEX IF NOT EXISTS idx_coordinated_sessions_created_desc 
      ON neoquest.coordinated_sessions(created_at DESC);
      
      -- Players session readiness indexes
      CREATE INDEX IF NOT EXISTS idx_players_session_ready_active 
      ON neoquest.players(session_ready, ready_timestamp) 
      WHERE is_active = TRUE;
      
      CREATE INDEX IF NOT EXISTS idx_players_ready_count 
      ON neoquest.players(is_active, session_ready) 
      WHERE is_active = TRUE;
      
      -- Session participants indexes
      CREATE INDEX IF NOT EXISTS idx_session_participants_session_status 
      ON neoquest.session_participants(session_id, final_status, joined_at);
      
      CREATE INDEX IF NOT EXISTS idx_session_participants_player_sessions 
      ON neoquest.session_participants(player_id, joined_at DESC);
      
      -- Session events indexes
      CREATE INDEX IF NOT EXISTS idx_session_events_session_type_time 
      ON neoquest.session_events(session_id, event_type, timestamp DESC);
      
      CREATE INDEX IF NOT EXISTS idx_session_events_timestamp_desc 
      ON neoquest.session_events(timestamp DESC);
      
      CREATE INDEX IF NOT EXISTS idx_session_events_type_time 
      ON neoquest.session_events(event_type, timestamp DESC);
      
      -- JSONB indexes for better performance
      CREATE INDEX IF NOT EXISTS idx_coordinated_sessions_config_gin 
      ON neoquest.coordinated_sessions USING GIN (session_config);
      
      CREATE INDEX IF NOT EXISTS idx_session_events_data_gin 
      ON neoquest.session_events USING GIN (event_data);
      
    `);
  }).then(function() {
    console.log('  ✅ Created performance indexes');
    
    return db.runSql(`
      SET search_path TO neoquest, public;
      
      -- ===============================================
      -- HELPER VIEWS
      -- ===============================================
      
      -- Current session status view with proper NULL handling
      CREATE OR REPLACE VIEW neoquest.current_session_status AS
      SELECT 
        cs.id,
        cs.session_name,
        cs.status,
        cs.countdown_seconds,
        cs.countdown_start_time,
        cs.actual_start_time,
        cs.admin_message,
        cs.updated_at,
        
        -- Calculate remaining countdown with proper NULL handling
        CASE 
          WHEN cs.status = 'countdown' AND cs.countdown_start_time IS NOT NULL
          THEN GREATEST(0, cs.countdown_seconds - EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - cs.countdown_start_time))::INTEGER)
          ELSE 0 
        END as remaining_countdown,
        
        -- Player counts with COALESCE for NULL safety
        COALESCE(player_stats.total_players, 0) as total_players,
        COALESCE(player_stats.ready_players, 0) as ready_players,
        COALESCE(player_stats.pending_players, 0) as pending_players,
        
        -- Percentage calculation with division by zero protection
        CASE 
          WHEN player_stats.total_players > 0 
          THEN ROUND((player_stats.ready_players::NUMERIC / player_stats.total_players) * 100, 1)
          ELSE 0 
        END as ready_percentage,
        
        -- Additional useful fields
        cs.total_expected_players,
        CURRENT_TIMESTAMP as view_generated_at
        
      FROM neoquest.coordinated_sessions cs
      CROSS JOIN (
        SELECT 
          COUNT(*)::INTEGER as total_players,
          COUNT(*) FILTER (WHERE session_ready = TRUE)::INTEGER as ready_players,
          COUNT(*) FILTER (WHERE session_ready = FALSE OR session_ready IS NULL)::INTEGER as pending_players
        FROM neoquest.players 
        WHERE is_active = TRUE
      ) player_stats
      WHERE cs.id = (SELECT id FROM neoquest.coordinated_sessions ORDER BY created_at DESC LIMIT 1);
      
      COMMENT ON VIEW neoquest.current_session_status IS 'Current session status with live player counts and PostgreSQL-optimized calculations';
      
    `);
  }).then(function() {
    console.log('  ✅ Created helper views');
    
    return db.runSql(`
      SET search_path TO neoquest, public;
      
      -- ===============================================
      -- TRIGGERS FOR AUTOMATION
      -- ===============================================
      
      -- Function to update timestamp
      CREATE OR REPLACE FUNCTION neoquest.update_session_timestamp()
      RETURNS TRIGGER 
      LANGUAGE plpgsql
      AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP;
        RETURN NEW;
      END;
      $$;
      
      -- Trigger for coordinated_sessions
      DROP TRIGGER IF EXISTS trigger_coordinated_sessions_updated_at ON neoquest.coordinated_sessions;
      CREATE TRIGGER trigger_coordinated_sessions_updated_at
        BEFORE UPDATE ON neoquest.coordinated_sessions
        FOR EACH ROW
        EXECUTE FUNCTION neoquest.update_session_timestamp();
      
      -- Function to auto-log session events
      CREATE OR REPLACE FUNCTION neoquest.log_session_event()
      RETURNS TRIGGER 
      LANGUAGE plpgsql
      AS $$
      BEGIN
        -- Log status changes
        IF TG_OP = 'UPDATE' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
          INSERT INTO neoquest.session_events (session_id, event_type, event_data, triggered_by)
          VALUES (NEW.id, 'status_changed', jsonb_build_object(
            'old_status', OLD.status,
            'new_status', NEW.status,
            'admin_message', NEW.admin_message,
            'countdown_seconds', NEW.countdown_seconds,
            'change_timestamp', CURRENT_TIMESTAMP
          ), COALESCE(NEW.admin_user, 'system'));
        END IF;
        
        -- Log new sessions
        IF TG_OP = 'INSERT' THEN
          INSERT INTO neoquest.session_events (session_id, event_type, event_data, triggered_by)
          VALUES (NEW.id, 'session_created', jsonb_build_object(
            'session_name', NEW.session_name,
            'initial_status', NEW.status,
            'total_expected_players', NEW.total_expected_players
          ), COALESCE(NEW.admin_user, 'system'));
        END IF;
        
        RETURN NEW;
      END;
      $$;
      
      -- Trigger for session events
      DROP TRIGGER IF EXISTS trigger_log_session_events ON neoquest.coordinated_sessions;
      CREATE TRIGGER trigger_log_session_events
        AFTER INSERT OR UPDATE ON neoquest.coordinated_sessions
        FOR EACH ROW
        EXECUTE FUNCTION neoquest.log_session_event();
      
      -- Trigger for session_participants timestamp updates
      DROP TRIGGER IF EXISTS trigger_session_participants_updated_at ON neoquest.session_participants;
      CREATE TRIGGER trigger_session_participants_updated_at
        BEFORE UPDATE ON neoquest.session_participants
        FOR EACH ROW
        EXECUTE FUNCTION neoquest.update_session_timestamp();
      
    `);
  }).then(function() {
    console.log('  ✅ Created automation triggers and functions');
    
    return db.runSql(`
      SET search_path TO neoquest, public;
      
      -- ===============================================
      -- INITIAL DATA
      -- ===============================================
      
      -- Insert initial session only if no sessions exist
      INSERT INTO neoquest.coordinated_sessions (session_name, status, admin_message, admin_user, total_expected_players)
      SELECT 'Default Session', 'registration', 'Players can register and mark themselves ready', 'system', 0
      WHERE NOT EXISTS (SELECT 1 FROM neoquest.coordinated_sessions);
      
    `);
  }).then(function() {
    console.log('  ✅ Added initial session data');
    console.log('🎉 Game session management system migration completed successfully!');
  });
};

exports.down = function(db) {
  console.log('🔄 Removing game session management system...');
  
  return db.runSql(`
    SET search_path TO neoquest, public;
    
    -- Drop triggers first
    DROP TRIGGER IF EXISTS trigger_session_participants_updated_at ON neoquest.session_participants;
    DROP TRIGGER IF EXISTS trigger_log_session_events ON neoquest.coordinated_sessions;
    DROP TRIGGER IF EXISTS trigger_coordinated_sessions_updated_at ON neoquest.coordinated_sessions;
    
    -- Drop functions
    DROP FUNCTION IF EXISTS neoquest.log_session_event();
    DROP FUNCTION IF EXISTS neoquest.update_session_timestamp();
    
    -- Drop views
    DROP VIEW IF EXISTS neoquest.current_session_status;
    
    -- Drop indexes
    DROP INDEX IF EXISTS neoquest.idx_session_events_data_gin;
    DROP INDEX IF EXISTS neoquest.idx_coordinated_sessions_config_gin;
    DROP INDEX IF EXISTS neoquest.idx_session_events_type_time;
    DROP INDEX IF EXISTS neoquest.idx_session_events_timestamp_desc;
    DROP INDEX IF EXISTS neoquest.idx_session_events_session_type_time;
    DROP INDEX IF EXISTS neoquest.idx_session_participants_player_sessions;
    DROP INDEX IF EXISTS neoquest.idx_session_participants_session_status;
    DROP INDEX IF EXISTS neoquest.idx_players_ready_count;
    DROP INDEX IF EXISTS neoquest.idx_players_session_ready_active;
    DROP INDEX IF EXISTS neoquest.idx_coordinated_sessions_created_desc;
    DROP INDEX IF EXISTS neoquest.idx_coordinated_sessions_active_countdown;
    DROP INDEX IF EXISTS neoquest.idx_coordinated_sessions_status;
    
    -- Drop tables in reverse dependency order
    DROP TABLE IF EXISTS neoquest.session_events;
    DROP TABLE IF EXISTS neoquest.session_participants;
    DROP TABLE IF EXISTS neoquest.coordinated_sessions;
    
  `).then(function() {
    return db.runSql(`
      SET search_path TO neoquest, public;
      
      -- Remove columns from players table
      DO $$
      BEGIN
        -- Drop constraint first if it exists
        IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema = 'neoquest' AND table_name = 'players' AND constraint_name = 'players_ready_timestamp_logic') THEN
          ALTER TABLE neoquest.players DROP CONSTRAINT players_ready_timestamp_logic;
        END IF;
        
        -- Drop columns if they exist
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'neoquest' AND table_name = 'players' AND column_name = 'ready_device_info') THEN
          ALTER TABLE neoquest.players DROP COLUMN ready_device_info;
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'neoquest' AND table_name = 'players' AND column_name = 'session_joined_at') THEN
          ALTER TABLE neoquest.players DROP COLUMN session_joined_at;
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'neoquest' AND table_name = 'players' AND column_name = 'ready_timestamp') THEN
          ALTER TABLE neoquest.players DROP COLUMN ready_timestamp;
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'neoquest' AND table_name = 'players' AND column_name = 'session_ready') THEN
          ALTER TABLE neoquest.players DROP COLUMN session_ready;
        END IF;
      END $$;
      
    `);
  }).then(function() {
    return db.runSql(`
      SET search_path TO neoquest, public;
      
      -- Drop enum type
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'session_status_enum' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'neoquest')) THEN
          DROP TYPE neoquest.session_status_enum;
        END IF;
      END $$;
      
    `);
  }).then(function() {
    console.log('🎉 Game session management system rollback completed successfully!');
  });
};

exports._meta = {
  "version": 1,
  "loadOrder": 10
};