/**
 * File: ../neoquest_db/migrations/19920214000001-init-new-quest-schema.js
 * 
 */

'use strict';

var dbm;
var type;
var seed;

/**
 * We receive the dbmigrate dependency from dbmigrate initially.
 * This enables us to not have to rely on NODE_PATH.
 */
exports.setup = function(options, seedLink) {
  dbm = options.dbmigrate;
  type = dbm.dataType;
  seed = seedLink;
};

exports.up = function(db) {
  return db.runSql(`
    -- ===============================================
    -- NeoQuest Complete Database Schema
    -- Supports all complexity levels (1-5)
    -- ===============================================
    
    -- Schema erstellen
    CREATE SCHEMA IF NOT EXISTS neoquest;
    
    -- Schema als Standard setzen
    SET search_path TO neoquest, public;
    
    -- -----------------------------------------------
    -- ENUM Types
    -- -----------------------------------------------
    
    -- Game mode types
    CREATE TYPE neoquest.game_mode AS ENUM ('competitive', 'individual', 'team', 'tutorial');
    
    -- Game complexity levels
    CREATE TYPE neoquest.complexity_level AS ENUM (
        'simple_race', 
        'hint_enhanced_race', 
        'multi_checkpoint_adventure', 
        'puzzle_driven_quest', 
        'meta_puzzle_system'
    );
    
    -- Checkpoint types
    CREATE TYPE neoquest.checkpoint_type AS ENUM ('start', 'intermediate', 'finish');
    
    -- Puzzle types
    CREATE TYPE neoquest.puzzle_type AS ENUM (
        'boolean', 
        'integer', 
        'number', 
        'text', 
        'multiple_choice', 
        'fill_in_blanks'
    );
    
    -- Session status
    CREATE TYPE neoquest.session_status AS ENUM ('created', 'started', 'paused', 'completed', 'abandoned');
    
    -- Upload status
    CREATE TYPE neoquest.upload_status AS ENUM ('pending', 'uploading', 'completed', 'failed', 'cancelled');
    
    -- Verification method
    CREATE TYPE neoquest.verification_method AS ENUM ('gps', 'qr_code', 'manual');
    
    -- -----------------------------------------------
    -- Core Game Management
    -- -----------------------------------------------
    
    -- Games table (erweitert von original)
    CREATE TABLE neoquest.games (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        game_type neoquest.game_mode DEFAULT 'competitive',
        complexity_level neoquest.complexity_level DEFAULT 'simple_race',
        game_config JSONB NOT NULL DEFAULT '{}',
        start_audio_path VARCHAR(500),
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Players table (clean modern structure)
    CREATE TABLE neoquest.players (
        id SERIAL PRIMARY KEY,
        token VARCHAR(255),
        name VARCHAR(255),
        email VARCHAR(255),
        game_id INTEGER REFERENCES neoquest.games(id),
        game_title VARCHAR(255),           -- Für QR-Code Display
        qr_code_content TEXT,              -- Kompletter QR-Code Text
        registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_active BOOLEAN DEFAULT TRUE,
        player_config JSONB DEFAULT '{}'
    );
    
    -- -----------------------------------------------
    -- Checkpoints & Route Management
    -- -----------------------------------------------
    
    -- Checkpoints table (clean modern structure)
    CREATE TABLE neoquest.checkpoints (
        id SERIAL PRIMARY KEY,
        game_id INTEGER REFERENCES neoquest.games(id) ON DELETE CASCADE,
        checkpoint_order INTEGER NOT NULL,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        latitude DECIMAL(10, 8) NOT NULL,
        longitude DECIMAL(11, 8) NOT NULL,
        radius INTEGER DEFAULT 20, -- Meters
        checkpoint_type neoquest.checkpoint_type DEFAULT 'intermediate',
        qr_code_content VARCHAR(255), -- QR code for verification
        is_required BOOLEAN DEFAULT TRUE,
        min_stay_duration INTEGER DEFAULT 0, -- Seconds
        checkpoint_config JSONB DEFAULT '{}',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(game_id, checkpoint_order)
    );
    
    -- -----------------------------------------------
    -- Puzzle System
    -- -----------------------------------------------
    
    -- Puzzles table (clean modern structure)
    CREATE TABLE neoquest.puzzles (
        id SERIAL PRIMARY KEY,
        game_id INTEGER REFERENCES neoquest.games(id) ON DELETE CASCADE,
        puzzle_id VARCHAR(50) NOT NULL, -- puzzle001, puzzle002, etc.
        checkpoint_id INTEGER REFERENCES neoquest.checkpoints(id) ON DELETE SET NULL,
        title VARCHAR(255) NOT NULL,
        question TEXT NOT NULL,
        puzzle_type neoquest.puzzle_type DEFAULT 'text',
        puzzle_config JSONB NOT NULL DEFAULT '{}',
        points INTEGER DEFAULT 100,
        max_attempts INTEGER DEFAULT 3,
        time_limit INTEGER, -- Seconds, NULL = no limit
        difficulty VARCHAR(20) DEFAULT 'medium' 
            CHECK (difficulty IN ('easy', 'medium', 'hard', 'expert')),
        unlock_condition VARCHAR(30) DEFAULT 'immediate'
            CHECK (unlock_condition IN ('immediate', 'location_based', 'time_based', 'puzzle_solved')),
        unlock_config JSONB DEFAULT '{}',
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(game_id, puzzle_id)
    );
    
    -- -----------------------------------------------
    -- Hints System
    -- -----------------------------------------------
    
    -- Hints table (new)
    CREATE TABLE neoquest.hints (
        id SERIAL PRIMARY KEY,
        game_id INTEGER REFERENCES neoquest.games(id) ON DELETE CASCADE,
        hint_id VARCHAR(50) NOT NULL, -- hint_001, main_hint_001, etc.
        puzzle_id VARCHAR(50), -- NULL for general game hints
        title VARCHAR(255),
        hint_text TEXT NOT NULL,
        media_file VARCHAR(255), -- puzzle001_hint01.mp3
        point_cost INTEGER DEFAULT 0,
        unlock_condition VARCHAR(30) DEFAULT 'immediate'
            CHECK (unlock_condition IN ('immediate', 'puzzle_solved', 'time_delay', 'location_based')),
        unlock_config JSONB DEFAULT '{}',
        hint_order INTEGER DEFAULT 1, -- Order within puzzle/game
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(game_id, hint_id),
        FOREIGN KEY (game_id, puzzle_id) REFERENCES neoquest.puzzles(game_id, puzzle_id) DEFERRABLE
    );
    
    -- -----------------------------------------------
    -- Player Session Management
    -- -----------------------------------------------
    
    -- Player Game Assignments (simplified)
    CREATE TABLE neoquest.player_games (
        id SERIAL PRIMARY KEY,
        player_id INTEGER REFERENCES neoquest.players(id) ON DELETE CASCADE,
        game_id INTEGER REFERENCES neoquest.games(id) ON DELETE CASCADE,
        assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        started_at TIMESTAMP,
        completed_at TIMESTAMP,
        UNIQUE(player_id, game_id)
    );
    
    -- Game Sessions table (new - erweiterte Session-Verwaltung)
    CREATE TABLE neoquest.game_sessions (
        id SERIAL PRIMARY KEY,
        player_id INTEGER REFERENCES neoquest.players(id) ON DELETE CASCADE,
        game_id INTEGER REFERENCES neoquest.games(id) ON DELETE CASCADE,
        session_token VARCHAR(255) UNIQUE NOT NULL,
        start_time TIMESTAMP,
        end_time TIMESTAMP,
        game_state JSONB NOT NULL DEFAULT '{}',
        final_score INTEGER,
        session_status neoquest.session_status DEFAULT 'created',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- -----------------------------------------------
    -- Player Actions & Tracking
    -- -----------------------------------------------
    
    -- Checkpoint Visits (clean modern structure)
    CREATE TABLE neoquest.checkpoint_visits (
        id SERIAL PRIMARY KEY,
        session_id INTEGER REFERENCES neoquest.game_sessions(id) ON DELETE CASCADE,
        checkpoint_id INTEGER REFERENCES neoquest.checkpoints(id) ON DELETE CASCADE,
        arrival_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        departure_time TIMESTAMP,
        latitude DECIMAL(10, 8),
        longitude DECIMAL(11, 8),
        accuracy DECIMAL(5, 2), -- GPS accuracy in meters
        verification_method neoquest.verification_method DEFAULT 'gps',
        verification_data JSONB DEFAULT '{}', -- QR content, manual verification details
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Quiz Results (simplified for modern system)
    CREATE TABLE neoquest.quiz_results (
        id SERIAL PRIMARY KEY,
        session_id INTEGER REFERENCES neoquest.game_sessions(id) ON DELETE CASCADE,
        puzzle_id VARCHAR(50) NOT NULL,
        given_answer JSONB,
        is_correct BOOLEAN,
        points_earned INTEGER DEFAULT 0,
        answered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Player puzzle attempts (clean modern structure)
    CREATE TABLE neoquest.puzzle_attempts (
        id SERIAL PRIMARY KEY,
        session_id INTEGER REFERENCES neoquest.game_sessions(id) ON DELETE CASCADE,
        puzzle_id VARCHAR(50) NOT NULL,
        attempt_number INTEGER DEFAULT 1,
        submitted_answer JSONB NOT NULL, -- Store answer in flexible format
        is_correct BOOLEAN NOT NULL,
        points_earned INTEGER DEFAULT 0,
        time_taken INTEGER, -- Seconds from puzzle unlock to submission
        attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        attempt_context JSONB DEFAULT '{}' -- Location, hints used, etc.
    );
    
    -- Player hint usage (clean modern structure)
    CREATE TABLE neoquest.hint_usage (
        id SERIAL PRIMARY KEY,
        session_id INTEGER REFERENCES neoquest.game_sessions(id) ON DELETE CASCADE,
        hint_id VARCHAR(50) NOT NULL,
        points_cost INTEGER NOT NULL,
        used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        usage_context JSONB DEFAULT '{}' -- Location, time in game, etc.
    );
    
    -- -----------------------------------------------
    -- GPS Tracking & Media
    -- -----------------------------------------------
    
    -- GPS Tracks (clean modern structure)
    CREATE TABLE neoquest.gps_tracks (
        id SERIAL PRIMARY KEY,
        session_id INTEGER REFERENCES neoquest.game_sessions(id) ON DELETE CASCADE,
        latitude DECIMAL(10, 8) NOT NULL,
        longitude DECIMAL(11, 8) NOT NULL,
        altitude DECIMAL(7, 2),
        accuracy DECIMAL(5, 2),
        speed DECIMAL(5, 2), -- km/h
        bearing DECIMAL(5, 2), -- degrees
        timestamp TIMESTAMP NOT NULL,
        track_context JSONB DEFAULT '{}' -- Battery level, network status, etc.
    );
    
    -- Media Files (erweitert von original)
    CREATE TABLE neoquest.media_files (
        id SERIAL PRIMARY KEY,
        filename VARCHAR(255) NOT NULL,
        original_name VARCHAR(255),
        file_path VARCHAR(500) NOT NULL,
        file_type VARCHAR(100),
        file_size INTEGER,
        uploaded_by INTEGER REFERENCES neoquest.players(id),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Photo uploads (clean modern structure)
    CREATE TABLE neoquest.photo_uploads (
        id SERIAL PRIMARY KEY,
        session_id INTEGER REFERENCES neoquest.game_sessions(id) ON DELETE CASCADE,
        checkpoint_id INTEGER REFERENCES neoquest.checkpoints(id) ON DELETE SET NULL,
        puzzle_id VARCHAR(50),
        file_path VARCHAR(500) NOT NULL,
        original_filename VARCHAR(255),
        file_size INTEGER,
        mime_type VARCHAR(100),
        latitude DECIMAL(10, 8),
        longitude DECIMAL(11, 8),
        taken_at TIMESTAMP,
        uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        photo_metadata JSONB DEFAULT '{}' -- EXIF data, device info, etc.
    );
    
    -- -----------------------------------------------
    -- Upload Queue & File Management
    -- -----------------------------------------------
    
    -- Upload Queue (clean modern structure)
    CREATE TABLE neoquest.upload_queue (
        id SERIAL PRIMARY KEY,
        session_id INTEGER REFERENCES neoquest.game_sessions(id) ON DELETE CASCADE,
        upload_type VARCHAR(50) NOT NULL CHECK (upload_type IN ('gps_track', 'photo', 'quiz_results', 'game_results', 'puzzle_answer', 'session_data')),
        file_path VARCHAR(500),
        upload_data JSONB,
        status neoquest.upload_status DEFAULT 'pending',
        priority INTEGER DEFAULT 5, -- 1 = highest, 10 = lowest
        retry_count INTEGER DEFAULT 0,
        max_retries INTEGER DEFAULT 3,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        processed_at TIMESTAMP,
        completed_at TIMESTAMP,
        error_message TEXT
    );
    
    -- -----------------------------------------------
    -- Game Configuration & Admin
    -- -----------------------------------------------
    
    -- Game Configuration (erweitert von original)
    CREATE TABLE neoquest.game_config (
        id SERIAL PRIMARY KEY,
        game_id INTEGER REFERENCES neoquest.games(id) ON DELETE CASCADE,
        config_key VARCHAR(100) NOT NULL,
        config_value TEXT,
        config_type VARCHAR(20) DEFAULT 'string' CHECK (config_type IN ('string', 'number', 'boolean', 'json')),
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(game_id, config_key)
    );
    
    -- ESP32 Commands Log (erweitert von original)
    CREATE TABLE neoquest.esp32_commands (
        id SERIAL PRIMARY KEY,
        command VARCHAR(255) NOT NULL,
        target_ip VARCHAR(15),
        game_id INTEGER REFERENCES neoquest.games(id) ON DELETE SET NULL,
        sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        status VARCHAR(50) DEFAULT 'sent' CHECK (status IN ('sent', 'acknowledged', 'failed')),
        response TEXT,
        retry_count INTEGER DEFAULT 0
    );
    
    -- -----------------------------------------------
    -- Analytics & Reporting
    -- -----------------------------------------------
    
    -- Game statistics (new)
    CREATE TABLE neoquest.game_statistics (
        id SERIAL PRIMARY KEY,
        game_id INTEGER REFERENCES neoquest.games(id) ON DELETE CASCADE,
        stat_date DATE NOT NULL,
        total_players INTEGER DEFAULT 0,
        completed_sessions INTEGER DEFAULT 0,
        average_completion_time INTEGER, -- seconds
        average_score DECIMAL(8, 2),
        most_difficult_puzzle VARCHAR(50),
        most_used_hint VARCHAR(50),
        statistics_data JSONB DEFAULT '{}',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(game_id, stat_date)
    );
    
    -- Leaderboards (new)
    CREATE TABLE neoquest.leaderboards (
        id SERIAL PRIMARY KEY,
        game_id INTEGER REFERENCES neoquest.games(id) ON DELETE CASCADE,
        session_id INTEGER REFERENCES neoquest.game_sessions(id) ON DELETE CASCADE,
        player_id INTEGER REFERENCES neoquest.players(id) ON DELETE CASCADE,
        player_name VARCHAR(255) NOT NULL,
        final_score INTEGER NOT NULL,
        completion_time INTEGER NOT NULL, -- seconds
        rank_position INTEGER,
        leaderboard_type VARCHAR(30) DEFAULT 'overall' 
            CHECK (leaderboard_type IN ('overall', 'daily', 'weekly', 'monthly')),
        additional_metrics JSONB DEFAULT '{}', -- puzzle accuracy, hints used, etc.
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- -----------------------------------------------
    -- Indexes for Performance
    -- -----------------------------------------------
    
    -- Game and session indexes
    CREATE INDEX idx_games_active ON neoquest.games(is_active) WHERE is_active = true;
    CREATE INDEX idx_game_sessions_status ON neoquest.game_sessions(session_status);
    CREATE INDEX idx_game_sessions_player_game ON neoquest.game_sessions(player_id, game_id);
    CREATE INDEX idx_players_token ON neoquest.players(token);
    CREATE INDEX idx_players_game ON neoquest.players(game_id);
    
    -- Location-based indexes
    CREATE INDEX idx_checkpoints_game_order ON neoquest.checkpoints(game_id, checkpoint_order);
    CREATE INDEX idx_gps_tracks_session_time ON neoquest.gps_tracks(session_id, timestamp);
    CREATE INDEX idx_checkpoint_visits_session ON neoquest.checkpoint_visits(session_id, arrival_time);
    
    -- Puzzle and hint indexes
    CREATE INDEX idx_puzzles_game_active ON neoquest.puzzles(game_id, is_active) WHERE is_active = true;
    CREATE INDEX idx_hints_game_active ON neoquest.hints(game_id, is_active) WHERE is_active = true;
    CREATE INDEX idx_puzzle_attempts_session ON neoquest.puzzle_attempts(session_id, puzzle_id);
    
    -- Upload and media indexes
    CREATE INDEX idx_upload_queue_status ON neoquest.upload_queue(status) WHERE status IN ('pending', 'failed');
    CREATE INDEX idx_photo_uploads_session ON neoquest.photo_uploads(session_id, uploaded_at);
    
    -- Analytics indexes
    CREATE INDEX idx_leaderboards_game_score ON neoquest.leaderboards(game_id, final_score DESC);
    CREATE INDEX idx_game_statistics_date ON neoquest.game_statistics(game_id, stat_date);
    
    -- -----------------------------------------------
    -- Views for Common Queries
    -- -----------------------------------------------
    
    -- Active games with player counts
    CREATE VIEW neoquest.active_games_summary AS
    SELECT 
        g.id,
        g.name,
        g.game_type,
        g.complexity_level,
        COUNT(DISTINCT p.id) as registered_players,
        COUNT(DISTINCT gs.id) as total_sessions,
        COUNT(DISTINCT gs.id) FILTER (WHERE gs.session_status = 'completed') as completed_sessions
    FROM neoquest.games g
    LEFT JOIN neoquest.players p ON g.id = p.game_id
    LEFT JOIN neoquest.game_sessions gs ON g.id = gs.game_id
    WHERE g.is_active = true
    GROUP BY g.id, g.name, g.game_type, g.complexity_level;
    
    -- Current player sessions
    CREATE VIEW neoquest.active_player_sessions AS
    SELECT 
        gs.id as session_id,
        gs.session_token,
        p.name as player_name,
        g.name as game_name,
        gs.session_status,
        gs.start_time,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - gs.start_time))::INTEGER as elapsed_seconds,
        gs.game_state->>'current_points' as current_points
    FROM neoquest.game_sessions gs
    JOIN neoquest.players p ON gs.player_id = p.id
    JOIN neoquest.games g ON gs.game_id = g.id
    WHERE gs.session_status IN ('started', 'paused');
    
    -- -----------------------------------------------
    -- Triggers for Automatic Updates
    -- -----------------------------------------------
    
    -- Update game_sessions.updated_at on game_state changes
    CREATE OR REPLACE FUNCTION neoquest.update_session_timestamp()
    RETURNS TRIGGER AS $$
    BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    
    CREATE TRIGGER trigger_update_session_timestamp
        BEFORE UPDATE ON neoquest.game_sessions
        FOR EACH ROW
        EXECUTE FUNCTION neoquest.update_session_timestamp();
    
    -- Auto-calculate leaderboard positions
    CREATE OR REPLACE FUNCTION neoquest.update_leaderboard_positions()
    RETURNS TRIGGER AS $$
    BEGIN
        -- Recalculate ranks for the affected game
        UPDATE neoquest.leaderboards 
        SET rank_position = ranked.new_rank
        FROM (
            SELECT id, ROW_NUMBER() OVER (ORDER BY final_score DESC, completion_time ASC) as new_rank
            FROM neoquest.leaderboards 
            WHERE game_id = COALESCE(NEW.game_id, OLD.game_id)
            AND leaderboard_type = COALESCE(NEW.leaderboard_type, OLD.leaderboard_type, 'overall')
        ) ranked
        WHERE neoquest.leaderboards.id = ranked.id;
        
        RETURN COALESCE(NEW, OLD);
    END;
    $$ LANGUAGE plpgsql;
    
    CREATE TRIGGER trigger_update_leaderboard_positions
        AFTER INSERT OR UPDATE OR DELETE ON neoquest.leaderboards
        FOR EACH ROW
        EXECUTE FUNCTION neoquest.update_leaderboard_positions();
  `);
};

exports.down = function(db) {
  return db.runSql(`
    -- Drop all triggers first
    DROP TRIGGER IF EXISTS trigger_update_leaderboard_positions ON neoquest.leaderboards;
    DROP TRIGGER IF EXISTS trigger_update_session_timestamp ON neoquest.game_sessions;
    
    -- Drop all functions
    DROP FUNCTION IF EXISTS neoquest.update_leaderboard_positions();
    DROP FUNCTION IF EXISTS neoquest.update_session_timestamp();
    
    -- Drop all views
    DROP VIEW IF EXISTS neoquest.active_player_sessions;
    DROP VIEW IF EXISTS neoquest.active_games_summary;
    
    -- Drop all tables in reverse order (wegen FK-Constraints)
    DROP TABLE IF EXISTS neoquest.leaderboards CASCADE;
    DROP TABLE IF EXISTS neoquest.game_statistics CASCADE;
    DROP TABLE IF EXISTS neoquest.esp32_commands CASCADE;
    DROP TABLE IF EXISTS neoquest.game_config CASCADE;
    DROP TABLE IF EXISTS neoquest.upload_queue CASCADE;
    DROP TABLE IF EXISTS neoquest.photo_uploads CASCADE;
    DROP TABLE IF EXISTS neoquest.media_files CASCADE;
    DROP TABLE IF EXISTS neoquest.gps_tracks CASCADE;
    DROP TABLE IF EXISTS neoquest.hint_usage CASCADE;
    DROP TABLE IF EXISTS neoquest.puzzle_attempts CASCADE;
    DROP TABLE IF EXISTS neoquest.quiz_results CASCADE;
    DROP TABLE IF EXISTS neoquest.checkpoint_visits CASCADE;
    DROP TABLE IF EXISTS neoquest.game_sessions CASCADE;
    DROP TABLE IF EXISTS neoquest.player_games CASCADE;
    DROP TABLE IF EXISTS neoquest.hints CASCADE;
    DROP TABLE IF EXISTS neoquest.puzzles CASCADE;
    DROP TABLE IF EXISTS neoquest.checkpoints CASCADE;
    DROP TABLE IF EXISTS neoquest.players CASCADE;
    DROP TABLE IF EXISTS neoquest.games CASCADE;
    
    -- Drop all ENUM types
    DROP TYPE IF EXISTS neoquest.verification_method;
    DROP TYPE IF EXISTS neoquest.upload_status;
    DROP TYPE IF EXISTS neoquest.session_status;
    DROP TYPE IF EXISTS neoquest.puzzle_type;
    DROP TYPE IF EXISTS neoquest.checkpoint_type;
    DROP TYPE IF EXISTS neoquest.complexity_level;
    DROP TYPE IF EXISTS neoquest.game_mode;
    
    -- Schema löschen (falls gewünscht)
    -- DROP SCHEMA IF EXISTS neoquest CASCADE;
  `);
};

exports._meta = {
  "version": 1
};