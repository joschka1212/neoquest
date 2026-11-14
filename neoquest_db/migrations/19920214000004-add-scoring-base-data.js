/**
 * Migration: Add Scoring System to Puzzles Table
 * File: ../neoquest_db/migrations/19920214000004-add-scoring-base-data.js
 * 
 * Usage:
 * npm run migrate:up   - Apply migration
 * npm run migrate:down - Rollback migration
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

/**
 * Apply migration - Add scoring columns
 */
exports.up = function(db) {
  return db.runSql(`
    -- Add scoring columns to puzzles table (one by one for PostgreSQL compatibility)
    ALTER TABLE neoquest.puzzles 
    ADD COLUMN IF NOT EXISTS base_points INTEGER DEFAULT 100;

    ALTER TABLE neoquest.puzzles 
    ADD COLUMN IF NOT EXISTS hint_penalty INTEGER DEFAULT 20;

    ALTER TABLE neoquest.puzzles 
    ADD COLUMN IF NOT EXISTS time_bonus_max INTEGER DEFAULT 50;

    ALTER TABLE neoquest.puzzles 
    ADD COLUMN IF NOT EXISTS time_limit_minutes INTEGER DEFAULT 10;

    ALTER TABLE neoquest.puzzles 
    ADD COLUMN IF NOT EXISTS has_time_limit BOOLEAN DEFAULT TRUE;

    ALTER TABLE neoquest.puzzles 
    ADD COLUMN IF NOT EXISTS scoring_type VARCHAR(20) DEFAULT 'standard';

    -- Add comments for documentation
    COMMENT ON COLUMN neoquest.puzzles.base_points IS 'Base points awarded for solving the puzzle';
    COMMENT ON COLUMN neoquest.puzzles.hint_penalty IS 'Points deducted per hint used';
    COMMENT ON COLUMN neoquest.puzzles.time_bonus_max IS 'Maximum bonus points for fast solving';
    COMMENT ON COLUMN neoquest.puzzles.time_limit_minutes IS 'Time limit for puzzle in minutes';
    COMMENT ON COLUMN neoquest.puzzles.has_time_limit IS 'Whether this puzzle has a time limit';
    COMMENT ON COLUMN neoquest.puzzles.scoring_type IS 'Scoring algorithm: standard, competitive, exploration';

    -- Create index for scoring queries
    CREATE INDEX IF NOT EXISTS idx_puzzles_scoring 
    ON neoquest.puzzles(base_points, scoring_type, has_time_limit);

    -- Create view for puzzle scoring summary
    CREATE OR REPLACE VIEW neoquest.puzzle_scoring_summary AS
    SELECT 
        p.id,
        p.title,
        p.base_points,
        p.hint_penalty,
        p.time_bonus_max,
        p.time_limit_minutes,
        p.has_time_limit,
        p.scoring_type,
        c.name as checkpoint_name,
        g.name as game_name,
        c.checkpoint_order,
        p.puzzle_id
    FROM neoquest.puzzles p
    JOIN neoquest.checkpoints c ON p.checkpoint_id = c.id
    JOIN neoquest.games g ON c.game_id = g.id
    WHERE p.is_active = TRUE AND g.is_active = TRUE
    ORDER BY g.id, c.checkpoint_order, p.puzzle_id;
  `).then(function() {
    
    // Update existing puzzles with sample scoring data (if they exist)
    return db.runSql(`
      DO $$
      BEGIN
          -- Update puzzle 1 if it exists
          IF EXISTS (SELECT 1 FROM neoquest.puzzles WHERE id = 1) THEN
              UPDATE neoquest.puzzles SET 
                  base_points = 100,
                  hint_penalty = 15,
                  time_bonus_max = 30,
                  time_limit_minutes = 8,
                  has_time_limit = TRUE,
                  scoring_type = 'standard'
              WHERE id = 1;
              RAISE NOTICE 'Updated scoring for puzzle ID 1';
          END IF;

          -- Update puzzle 2 if it exists
          IF EXISTS (SELECT 1 FROM neoquest.puzzles WHERE id = 2) THEN
              UPDATE neoquest.puzzles SET 
                  base_points = 150,
                  hint_penalty = 20,
                  time_bonus_max = 50,
                  time_limit_minutes = 12,
                  has_time_limit = TRUE,
                  scoring_type = 'standard'
              WHERE id = 2;
              RAISE NOTICE 'Updated scoring for puzzle ID 2';
          END IF;

          -- Update puzzle 3 if it exists
          IF EXISTS (SELECT 1 FROM neoquest.puzzles WHERE id = 3) THEN
              UPDATE neoquest.puzzles SET 
                  base_points = 200,
                  hint_penalty = 25,
                  time_bonus_max = 75,
                  time_limit_minutes = 15,
                  has_time_limit = TRUE,
                  scoring_type = 'competitive'
              WHERE id = 3;
              RAISE NOTICE 'Updated scoring for puzzle ID 3';
          END IF;
      END
      $$;
    `);
    
  }).then(function() {
    console.log('✅ Scoring system migration completed successfully');
    console.log('📊 Added columns: base_points, hint_penalty, time_bonus_max, time_limit_minutes, has_time_limit, scoring_type');
    console.log('📈 Created index: idx_puzzles_scoring');
    console.log('👁️ Created view: puzzle_scoring_summary');
  });
};

/**
 * Rollback migration - Remove scoring columns
 */
exports.down = function(db) {
  return db.runSql(`
    -- Drop view
    DROP VIEW IF EXISTS neoquest.puzzle_scoring_summary;
    
    -- Drop index
    DROP INDEX IF EXISTS neoquest.idx_puzzles_scoring;
    
    -- Remove scoring columns
    ALTER TABLE neoquest.puzzles DROP COLUMN IF EXISTS scoring_type;
    ALTER TABLE neoquest.puzzles DROP COLUMN IF EXISTS has_time_limit;
    ALTER TABLE neoquest.puzzles DROP COLUMN IF EXISTS time_limit_minutes;
    ALTER TABLE neoquest.puzzles DROP COLUMN IF EXISTS time_bonus_max;
    ALTER TABLE neoquest.puzzles DROP COLUMN IF EXISTS hint_penalty;
    ALTER TABLE neoquest.puzzles DROP COLUMN IF EXISTS base_points;
  `).then(function() {
    console.log('✅ Scoring system migration rolled back successfully');
    console.log('🗑️ Removed all scoring columns, index, and view');
  });
};

exports._meta = {
  "version": 1,
  "loadOrder": 3
};