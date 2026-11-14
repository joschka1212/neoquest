
// Migration 1: Add mission completion fields to neoquest.players table
// File: migrations/20250711120001-add-mission-completion-to-players.js


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
  console.log('🚀 Starting mission completion fields migration for neoquest schema...');
  
  // Set search path to neoquest schema first
  return db.runSql(`
    SET search_path TO neoquest, public;
  `).then(function() {
    console.log('  ✅ Set search path to neoquest schema');
    
    // Add mission_completed column (already exists from 19920214000005, but safe to add)
    return db.runSql(`
      ALTER TABLE neoquest.players ADD COLUMN IF NOT EXISTS mission_completed BOOLEAN DEFAULT FALSE;
    `);
  }).then(function() {
    console.log('  ✅ Added/verified mission_completed column');
    
    return db.runSql(`
      ALTER TABLE neoquest.players ADD COLUMN IF NOT EXISTS mission_upload_status VARCHAR(50) DEFAULT 'pending';
    `);
  }).then(function() {
    console.log('  ✅ Added mission_upload_status column');
    
    return db.runSql(`
      ALTER TABLE neoquest.players ADD COLUMN IF NOT EXISTS mission_completion_timestamp TIMESTAMP;
    `);
  }).then(function() {
    console.log('  ✅ Added mission_completion_timestamp column');
    
    return db.runSql(`
      ALTER TABLE neoquest.players ADD COLUMN IF NOT EXISTS final_mission_score INTEGER DEFAULT 0;
    `);
  }).then(function() {
    console.log('  ✅ Added final_mission_score column');
    
    return db.runSql(`
      CREATE INDEX IF NOT EXISTS idx_players_mission_completed ON neoquest.players(mission_completed);
    `);
  }).then(function() {
    return db.runSql(`
      CREATE INDEX IF NOT EXISTS idx_players_upload_status ON neoquest.players(mission_upload_status);
    `);
  }).then(function() {
    return db.runSql(`
      CREATE INDEX IF NOT EXISTS idx_players_final_mission_score ON neoquest.players(final_mission_score);
    `);
  }).then(function() {
    return db.runSql(`
      CREATE INDEX IF NOT EXISTS idx_players_mission_completion_timestamp ON neoquest.players(mission_completion_timestamp);
    `);
  }).then(function() {
    // Add helpful comments
    return db.runSql(`
      COMMENT ON COLUMN neoquest.players.mission_upload_status IS 'Upload status: pending, uploading, complete, failed';
    `);
  }).then(function() {
    return db.runSql(`
      COMMENT ON COLUMN neoquest.players.mission_completion_timestamp IS 'Timestamp when mission was completed (for upload system)';
    `);
  }).then(function() {
    return db.runSql(`
      COMMENT ON COLUMN neoquest.players.final_mission_score IS 'Final calculated score for mission results';
    `);
  }).then(function() {
    console.log('🎉 Mission completion fields migration completed successfully!');
  });
};

exports.down = function(db) {
  return db.runSql(`
    SET search_path TO neoquest, public;
  `).then(function() {
    return db.runSql(`
      DROP INDEX IF EXISTS neoquest.idx_players_mission_completion_timestamp;
    `);
  }).then(function() {
    return db.runSql(`
      DROP INDEX IF EXISTS neoquest.idx_players_final_mission_score;
    `);
  }).then(function() {
    return db.runSql(`
      DROP INDEX IF EXISTS neoquest.idx_players_upload_status;
    `);
  }).then(function() {
    return db.runSql(`
      DROP INDEX IF EXISTS neoquest.idx_players_mission_completed;
    `);
  }).then(function() {
    return db.runSql(`
      ALTER TABLE neoquest.players DROP COLUMN IF EXISTS mission_completion_timestamp;
    `);
  }).then(function() {
    return db.runSql(`
      ALTER TABLE neoquest.players DROP COLUMN IF EXISTS final_mission_score;
    `);
  }).then(function() {
    return db.runSql(`
      ALTER TABLE neoquest.players DROP COLUMN IF EXISTS mission_upload_status;
    `);
  }).then(function() {
    // Note: Keep mission_completed as it was added in earlier migration
    console.log('  ⚠️ Keeping mission_completed column (from earlier migration)');
  });
};

exports._meta = {
  "version": 1
};
