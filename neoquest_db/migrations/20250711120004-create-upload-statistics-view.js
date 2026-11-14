// Migration 4: Create upload statistics view in neoquest schema
// File: migrations/20250711120004-create-upload-statistics-view.js

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
  console.log('🚀 Creating upload_statistics view in neoquest schema...');
  
  return db.runSql(`
    SET search_path TO neoquest, public;
  `).then(function() {
    return db.runSql(`
      CREATE OR REPLACE VIEW neoquest.upload_statistics AS
      SELECT 
        p.id as player_id,
        p.name as player_name,
        p.token as player_token,
        p.email as player_email,
        p.game_id,
        p.game_title,
        
        -- Existing columns from neoquest.players
        COALESCE(p.game_completed, false) as mission_completed,
        COALESCE(p.total_score, 0) as total_score,
        COALESCE(p.completion_time, 0) as completion_time_seconds,
        
        -- New upload system columns
        COALESCE(p.mission_upload_status, 'pending') as mission_upload_status,
        COALESCE(p.final_mission_score, p.total_score, 0) as final_mission_score,
        p.mission_completion_timestamp,
        
        -- Upload progress (safe with COALESCE)
        COALESCE(COUNT(CASE WHEN mu.upload_type = 'route' AND mu.upload_status = 'complete' THEN 1 END) > 0, false) as route_uploaded,
        COALESCE(COUNT(CASE WHEN mu.upload_type = 'photos' AND mu.upload_status = 'complete' THEN 1 END), 0) as photos_uploaded,
        COALESCE(COUNT(CASE WHEN mu.upload_type = 'complete' AND mu.upload_status = 'complete' THEN 1 END) > 0, false) as mission_upload_complete,
        
        -- Mission results (safe with COALESCE)
        COALESCE(mr.total_distance_meters, 0) as total_distance_meters,
        COALESCE(mr.total_time_seconds, p.completion_time, 0) as total_time_seconds,
        COALESCE(mr.completion_time, p.mission_completion_timestamp) as result_completion_time,
        
        -- Upload timing
        MAX(mu.uploaded_at) as last_upload_at,
        MIN(mu.created_at) as first_upload_at,
        
        -- Player status
        p.registered_at,
        p.is_active
        
      FROM neoquest.players p
      LEFT JOIN neoquest.mission_uploads mu ON p.id = mu.player_id
      LEFT JOIN neoquest.mission_results mr ON p.id = mr.player_id
      GROUP BY p.id, p.name, p.token, p.email, p.game_id, p.game_title, 
               p.game_completed, p.total_score, p.completion_time, p.mission_upload_status, 
               p.final_mission_score, p.mission_completion_timestamp, p.registered_at, p.is_active,
               mr.total_distance_meters, mr.total_time_seconds, mr.completion_time;
    `);
  }).then(function() {
    return db.runSql(`
      COMMENT ON VIEW neoquest.upload_statistics IS 'Comprehensive view of player upload progress and mission results';
    `);
  }).then(function() {
    console.log('🎉 Upload statistics view migration completed successfully!');
  });
};

exports.down = function(db) {
  return db.runSql(`
    SET search_path TO neoquest, public;
  `).then(function() {
    return db.runSql(`
      DROP VIEW IF EXISTS neoquest.upload_statistics;
    `);
  });
};

exports._meta = {
  "version": 1
};