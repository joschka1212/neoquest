// file: neoquest_db/migrations/19920214000005-setup-completion-players.js
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
  return new Promise(async function(resolve, reject) {
    try {
      console.log('🚀 Adding player completion tracking fields...');
      
      // Add completion tracking columns
      await db.runSql(`
        ALTER TABLE neoquest.players 
        ADD COLUMN IF NOT EXISTS game_completed BOOLEAN DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS completion_time INTEGER DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS total_score INTEGER DEFAULT 0;
      `);
      
      console.log('✅ Columns added successfully');
      
      // Add comments for documentation
      await db.runSql(`
        COMMENT ON COLUMN neoquest.players.game_completed IS 'Whether player has completed the game';
        COMMENT ON COLUMN neoquest.players.completion_time IS 'Game completion time in seconds';
        COMMENT ON COLUMN neoquest.players.total_score IS 'Total score achieved by player';
      `);
      
      console.log('✅ Column comments added');
      
      // Create indices for performance
      await db.runSql(`
        CREATE INDEX IF NOT EXISTS idx_players_game_completed ON neoquest.players(game_completed);
        CREATE INDEX IF NOT EXISTS idx_players_completion_time ON neoquest.players(completion_time);
        CREATE INDEX IF NOT EXISTS idx_players_total_score ON neoquest.players(total_score);
      `);
      
      console.log('✅ Basic indices created');
      
      // Create composite index for leaderboard queries
      await db.runSql(`
        CREATE INDEX IF NOT EXISTS idx_players_game_leaderboard 
        ON neoquest.players(game_id, game_completed, total_score DESC, completion_time ASC)
        WHERE game_completed = true;
      `);
      
      console.log('✅ Leaderboard index created');
      
      // Update existing players to have default values
      await db.runSql(`
        UPDATE neoquest.players 
        SET 
          game_completed = FALSE,
          completion_time = NULL,
          total_score = 0
        WHERE game_completed IS NULL;
      `);
      
      console.log('✅ Existing players updated with default values');
      
      console.log('🎉 Player completion tracking migration completed successfully!');
      resolve();
      
    } catch (error) {
      console.error('❌ Migration failed:', error);
      reject(error);
    }
  });
};

exports.down = function(db) {
  return new Promise(async function(resolve, reject) {
    try {
      console.log('🔄 Removing player completion tracking fields...');
      
      // Drop indices first
      await db.runSql(`
        DROP INDEX IF EXISTS neoquest.idx_players_game_leaderboard;
        DROP INDEX IF EXISTS neoquest.idx_players_total_score;
        DROP INDEX IF EXISTS neoquest.idx_players_completion_time;
        DROP INDEX IF EXISTS neoquest.idx_players_game_completed;
      `);
      
      console.log('✅ Indices dropped');
      
      // Remove completion tracking columns
      await db.runSql(`
        ALTER TABLE neoquest.players 
        DROP COLUMN IF EXISTS game_completed,
        DROP COLUMN IF EXISTS completion_time,
        DROP COLUMN IF EXISTS total_score;
      `);
      
      console.log('✅ Columns removed');
      console.log('🎉 Rollback completed successfully!');
      resolve();
      
    } catch (error) {
      console.error('❌ Rollback failed:', error);
      reject(error);
    }
  });
};

exports._meta = {
  "version": 1
};