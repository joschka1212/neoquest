// Migration 3: Create mission_results table in neoquest schema
// File: migrations/20250711120003-create-mission-results-table.js

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
  console.log('🚀 Creating mission_results table in neoquest schema...');
  
  return db.runSql(`
    SET search_path TO neoquest, public;
  `).then(function() {
    return db.runSql(`
      CREATE TABLE IF NOT EXISTS neoquest.mission_results (
        id SERIAL PRIMARY KEY,
        player_id INTEGER NOT NULL REFERENCES neoquest.players(id) ON DELETE CASCADE,
        game_id INTEGER NOT NULL REFERENCES neoquest.games(id) ON DELETE CASCADE,
        route_data JSONB,
        checkpoints_reached JSONB,
        photos_taken JSONB,
        total_distance_meters FLOAT,
        total_time_seconds INTEGER,
        final_score INTEGER NOT NULL DEFAULT 0,
        completion_time TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
  }).then(function() {
    console.log('  ✅ Created mission_results table');
    
    return db.runSql(`
      ALTER TABLE neoquest.mission_results ADD CONSTRAINT unique_player_game 
      UNIQUE(player_id, game_id);
    `);
  }).then(function() {
    console.log('  ✅ Added unique constraint');
    
    return db.runSql(`
      CREATE INDEX IF NOT EXISTS idx_mission_results_player ON neoquest.mission_results(player_id);
    `);
  }).then(function() {
    return db.runSql(`
      CREATE INDEX IF NOT EXISTS idx_mission_results_game ON neoquest.mission_results(game_id);
    `);
  }).then(function() {
    return db.runSql(`
      CREATE INDEX IF NOT EXISTS idx_mission_results_score ON neoquest.mission_results(final_score DESC);
    `);
  }).then(function() {
    return db.runSql(`
      CREATE INDEX IF NOT EXISTS idx_mission_results_completion ON neoquest.mission_results(completion_time);
    `);
  }).then(function() {
    console.log('  ✅ Created all indexes');
    
    return db.runSql(`
      COMMENT ON TABLE neoquest.mission_results IS 'Complete mission results and analytics per player';
    `);
  }).then(function() {
    console.log('🎉 Mission results table migration completed successfully!');
  });
};

exports.down = function(db) {
  return db.runSql(`
    SET search_path TO neoquest, public;
  `).then(function() {
    return db.runSql(`
      DROP INDEX IF EXISTS neoquest.idx_mission_results_completion;
    `);
  }).then(function() {
    return db.runSql(`
      DROP INDEX IF EXISTS neoquest.idx_mission_results_score;
    `);
  }).then(function() {
    return db.runSql(`
      DROP INDEX IF EXISTS neoquest.idx_mission_results_game;
    `);
  }).then(function() {
    return db.runSql(`
      DROP INDEX IF EXISTS neoquest.idx_mission_results_player;
    `);
  }).then(function() {
    return db.runSql(`
      DROP TABLE IF EXISTS neoquest.mission_results;
    `);
  });
};

exports._meta = {
  "version": 1
};