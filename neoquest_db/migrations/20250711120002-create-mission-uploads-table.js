// Migration 2: Create mission_uploads table in neoquest schema
// File: migrations/20250711120002-create-mission-uploads-table.js

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
  console.log('🚀 Creating mission_uploads table in neoquest schema...');
  
  return db.runSql(`
    SET search_path TO neoquest, public;
  `).then(function() {
    return db.runSql(`
      CREATE TABLE IF NOT EXISTS neoquest.mission_uploads (
        id SERIAL PRIMARY KEY,
        player_id INTEGER NOT NULL REFERENCES neoquest.players(id) ON DELETE CASCADE,
        upload_type VARCHAR(50) NOT NULL,
        upload_status VARCHAR(50) DEFAULT 'pending',
        file_path VARCHAR(500),
        file_size INTEGER,
        metadata JSONB,
        uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
  }).then(function() {
    console.log('  ✅ Created mission_uploads table');
    
    return db.runSql(`
      ALTER TABLE neoquest.mission_uploads ADD CONSTRAINT check_upload_type 
      CHECK (upload_type IN ('route', 'photos', 'complete'));
    `);
  }).then(function() {
    return db.runSql(`
      ALTER TABLE neoquest.mission_uploads ADD CONSTRAINT check_upload_status 
      CHECK (upload_status IN ('pending', 'uploading', 'complete', 'failed'));
    `);
  }).then(function() {
    console.log('  ✅ Added constraints');
    
    return db.runSql(`
      CREATE INDEX IF NOT EXISTS idx_mission_uploads_player ON neoquest.mission_uploads(player_id);
    `);
  }).then(function() {
    return db.runSql(`
      CREATE INDEX IF NOT EXISTS idx_mission_uploads_type ON neoquest.mission_uploads(upload_type);
    `);
  }).then(function() {
    return db.runSql(`
      CREATE INDEX IF NOT EXISTS idx_mission_uploads_status ON neoquest.mission_uploads(upload_status);
    `);
  }).then(function() {
    return db.runSql(`
      CREATE INDEX IF NOT EXISTS idx_mission_uploads_created ON neoquest.mission_uploads(created_at);
    `);
  }).then(function() {
    console.log('  ✅ Created all indexes');
    
    return db.runSql(`
      COMMENT ON TABLE neoquest.mission_uploads IS 'Tracks individual file uploads per player';
    `);
  }).then(function() {
    console.log('🎉 Mission uploads table migration completed successfully!');
  });
};

exports.down = function(db) {
  return db.runSql(`
    SET search_path TO neoquest, public;
  `).then(function() {
    return db.runSql(`
      DROP INDEX IF EXISTS neoquest.idx_mission_uploads_created;
    `);
  }).then(function() {
    return db.runSql(`
      DROP INDEX IF EXISTS neoquest.idx_mission_uploads_status;
    `);
  }).then(function() {
    return db.runSql(`
      DROP INDEX IF EXISTS neoquest.idx_mission_uploads_type;
    `);
  }).then(function() {
    return db.runSql(`
      DROP INDEX IF EXISTS neoquest.idx_mission_uploads_player;
    `);
  }).then(function() {
    return db.runSql(`
      DROP TABLE IF EXISTS neoquest.mission_uploads;
    `);
  });
};

exports._meta = {
  "version": 1
};