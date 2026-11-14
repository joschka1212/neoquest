/**
 * File: ../neoquest_db/migrations/19920214000002-add-indexes.js
 * 
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
  return db.runSql(`
    -- ===============================================
    -- NeoQuest Performance Indexes
    -- Comprehensive indexing for all complexity levels
    -- ===============================================
    
    SET search_path TO neoquest, public;
    
    -- -----------------------------------------------
    -- Legacy/Original Indexes (removed - clean start)
    -- -----------------------------------------------
    
    -- Core performance indexes only
    CREATE INDEX IF NOT EXISTS idx_gps_tracks_session_timestamp 
    ON neoquest.gps_tracks(session_id, timestamp);
    
    CREATE INDEX IF NOT EXISTS idx_upload_queue_status_priority 
    ON neoquest.upload_queue(status, priority);
    
    CREATE INDEX IF NOT EXISTS idx_checkpoint_visits_session_checkpoint 
    ON neoquest.checkpoint_visits(session_id, checkpoint_id);
    
    CREATE INDEX IF NOT EXISTS idx_puzzles_game_puzzle 
    ON neoquest.puzzles(game_id, puzzle_id);
    
    CREATE INDEX IF NOT EXISTS idx_checkpoints_game_order 
    ON neoquest.checkpoints(game_id, checkpoint_order);
    
    -- -----------------------------------------------
    -- Core Game & Player Indexes
    -- -----------------------------------------------
    
    -- Games
    CREATE INDEX IF NOT EXISTS idx_games_active_type 
    ON neoquest.games(is_active, game_type);
    
    CREATE INDEX IF NOT EXISTS idx_games_complexity_active 
    ON neoquest.games(complexity_level, is_active);
    
    -- Players - token already has UNIQUE constraint (automatic index)
    -- Only add partial index for active players
    CREATE INDEX IF NOT EXISTS idx_players_token_active 
    ON neoquest.players(token);
    
    CREATE INDEX IF NOT EXISTS idx_players_game_status 
    ON neoquest.players(game_id, is_active);
    
    CREATE INDEX IF NOT EXISTS idx_players_registration_time 
    ON neoquest.players(registered_at);
    
    -- -----------------------------------------------
    -- Session Management Indexes
    -- -----------------------------------------------
    
    -- Game Sessions - session_token has UNIQUE constraint (automatic index)
    CREATE INDEX IF NOT EXISTS idx_game_sessions_player_status 
    ON neoquest.game_sessions(player_id, session_status);
    
    CREATE INDEX IF NOT EXISTS idx_game_sessions_game_status 
    ON neoquest.game_sessions(game_id, session_status);
    
    CREATE INDEX IF NOT EXISTS idx_game_sessions_start_time 
    ON neoquest.game_sessions(start_time);
    
    CREATE INDEX IF NOT EXISTS idx_game_sessions_active 
    ON neoquest.game_sessions(session_status, updated_at);
    
    -- Player Games (backward compatibility)
    CREATE INDEX IF NOT EXISTS idx_player_games_assignment 
    ON neoquest.player_games(player_id, game_id, assigned_at);
    
    CREATE INDEX IF NOT EXISTS idx_player_games_completion 
    ON neoquest.player_games(game_id, completed_at);
    
    -- -----------------------------------------------
    -- Checkpoint & Location Indexes
    -- -----------------------------------------------
    
    -- Checkpoints
    CREATE INDEX IF NOT EXISTS idx_checkpoints_game_type_order 
    ON neoquest.checkpoints(game_id, checkpoint_type, checkpoint_order);
    
    CREATE INDEX IF NOT EXISTS idx_checkpoints_location 
    ON neoquest.checkpoints(latitude, longitude);
    
    CREATE INDEX IF NOT EXISTS idx_checkpoints_required 
    ON neoquest.checkpoints(game_id, is_required);
    
    -- Checkpoint Visits (enhanced)
    CREATE INDEX IF NOT EXISTS idx_checkpoint_visits_session_time 
    ON neoquest.checkpoint_visits(session_id, arrival_time);
    
    CREATE INDEX IF NOT EXISTS idx_checkpoint_visits_verification 
    ON neoquest.checkpoint_visits(checkpoint_id, verification_method, arrival_time);
    
    CREATE INDEX IF NOT EXISTS idx_checkpoint_visits_location 
    ON neoquest.checkpoint_visits(latitude, longitude);
    
    -- -----------------------------------------------
    -- GPS & Tracking Indexes
    -- -----------------------------------------------
    
    CREATE INDEX IF NOT EXISTS idx_gps_tracks_session_timestamp 
    ON neoquest.gps_tracks(session_id, timestamp);
    
    CREATE INDEX IF NOT EXISTS idx_gps_tracks_location_time 
    ON neoquest.gps_tracks(latitude, longitude, timestamp);
    
    CREATE INDEX IF NOT EXISTS idx_gps_tracks_accuracy 
    ON neoquest.gps_tracks(session_id, accuracy, timestamp);
    
    -- -----------------------------------------------
    -- Puzzle System Indexes
    -- -----------------------------------------------
    
    -- Puzzles (enhanced)
    CREATE INDEX IF NOT EXISTS idx_puzzles_game_active_order 
    ON neoquest.puzzles(game_id, is_active, puzzle_id) WHERE is_active = true;
    
    CREATE INDEX IF NOT EXISTS idx_puzzles_checkpoint 
    ON neoquest.puzzles(checkpoint_id, is_active) WHERE checkpoint_id IS NOT NULL;
    
    CREATE INDEX IF NOT EXISTS idx_puzzles_type_difficulty 
    ON neoquest.puzzles(game_id, puzzle_type, difficulty);
    
    CREATE INDEX IF NOT EXISTS idx_puzzles_unlock_condition 
    ON neoquest.puzzles(game_id, unlock_condition, is_active) WHERE is_active = true;
    
    CREATE INDEX IF NOT EXISTS idx_puzzle_attempts_session_puzzle 
    ON neoquest.puzzle_attempts(session_id, puzzle_id, attempt_number);
    
    CREATE INDEX IF NOT EXISTS idx_puzzle_attempts_correct 
    ON neoquest.puzzle_attempts(puzzle_id, is_correct, attempted_at);
    
    CREATE INDEX IF NOT EXISTS idx_puzzle_attempts_performance 
    ON neoquest.puzzle_attempts(session_id, points_earned, time_taken);
    
    -- -----------------------------------------------
    -- Hints System Indexes
    -- -----------------------------------------------
    
    -- Hints
    CREATE INDEX IF NOT EXISTS idx_hints_game_active 
    ON neoquest.hints(game_id, is_active);
    
    CREATE INDEX IF NOT EXISTS idx_hints_puzzle_order 
    ON neoquest.hints(game_id, puzzle_id, hint_order);
    
    CREATE INDEX IF NOT EXISTS idx_hints_unlock_condition 
    ON neoquest.hints(game_id, unlock_condition, is_active);
    
    CREATE INDEX IF NOT EXISTS idx_hints_cost 
    ON neoquest.hints(game_id, point_cost, is_active);
    
    CREATE INDEX IF NOT EXISTS idx_hint_usage_session 
    ON neoquest.hint_usage(session_id, used_at);
    
    CREATE INDEX IF NOT EXISTS idx_hint_usage_hint_frequency 
    ON neoquest.hint_usage(hint_id, used_at);
    
    -- -----------------------------------------------
    -- Media & Upload Indexes
    -- -----------------------------------------------
    
    -- Upload Queue (enhanced)
    CREATE INDEX IF NOT EXISTS idx_upload_queue_session_type 
    ON neoquest.upload_queue(session_id, upload_type, status);
    
    CREATE INDEX IF NOT EXISTS idx_upload_queue_priority_status 
    ON neoquest.upload_queue(priority, status, created_at);
    
    CREATE INDEX IF NOT EXISTS idx_upload_queue_retry 
    ON neoquest.upload_queue(status, retry_count, created_at) 
    WHERE status = 'failed' AND retry_count < max_retries;
    
    -- Photo Uploads
    CREATE INDEX IF NOT EXISTS idx_photo_uploads_session_checkpoint 
    ON neoquest.photo_uploads(session_id, checkpoint_id, uploaded_at);
    
    CREATE INDEX IF NOT EXISTS idx_photo_uploads_location_time 
    ON neoquest.photo_uploads(latitude, longitude, taken_at);
    
    CREATE INDEX IF NOT EXISTS idx_photo_uploads_puzzle 
    ON neoquest.photo_uploads(puzzle_id, uploaded_at);
    
    -- Media Files
    CREATE INDEX IF NOT EXISTS idx_media_files_uploader_time 
    ON neoquest.media_files(uploaded_by, created_at);
    
    CREATE INDEX IF NOT EXISTS idx_media_files_type_size 
    ON neoquest.media_files(file_type, file_size);
    
    -- -----------------------------------------------
    -- Configuration & Admin Indexes
    -- -----------------------------------------------
    
    -- Game Config
    CREATE INDEX IF NOT EXISTS idx_game_config_key 
    ON neoquest.game_config(game_id, config_key);
    
    CREATE INDEX IF NOT EXISTS idx_game_config_type 
    ON neoquest.game_config(config_type, game_id);
    
    -- ESP32 Commands
    CREATE INDEX IF NOT EXISTS idx_esp32_commands_game_status 
    ON neoquest.esp32_commands(game_id, status, sent_at);
    
    CREATE INDEX IF NOT EXISTS idx_esp32_commands_target_time 
    ON neoquest.esp32_commands(target_ip, sent_at);
    
    CREATE INDEX IF NOT EXISTS idx_esp32_commands_retry 
    ON neoquest.esp32_commands(status, retry_count, sent_at) 
    WHERE status = 'failed' AND retry_count < 3;
    
    -- -----------------------------------------------
    -- Analytics & Reporting Indexes
    -- -----------------------------------------------
    
    -- -----------------------------------------------
    -- Leaderboards
    -- -----------------------------------------------
    
    CREATE INDEX IF NOT EXISTS idx_leaderboards_game_rank 
    ON neoquest.leaderboards(game_id, leaderboard_type, rank_position);
    
    CREATE INDEX IF NOT EXISTS idx_leaderboards_score_time 
    ON neoquest.leaderboards(game_id, final_score, completion_time);
    
    CREATE INDEX IF NOT EXISTS idx_leaderboards_player_performance 
    ON neoquest.leaderboards(player_id, final_score, created_at);
    
    CREATE INDEX IF NOT EXISTS idx_leaderboards_daily 
    ON neoquest.leaderboards(game_id, leaderboard_type, created_at);
    
    -- Game Statistics
    CREATE INDEX IF NOT EXISTS idx_game_statistics_date_range 
    ON neoquest.game_statistics(game_id, stat_date);
    
    CREATE INDEX IF NOT EXISTS idx_game_statistics_metrics 
    ON neoquest.game_statistics(game_id, average_score, completed_sessions);
    
    -- -----------------------------------------------
    -- Partial Indexes for Specific Scenarios
    -- -----------------------------------------------
    
    -- Active sessions only (simplified)
    CREATE INDEX IF NOT EXISTS idx_active_sessions_performance 
    ON neoquest.game_sessions(game_id, start_time, updated_at);
    
    -- Completed games only (simplified)
    CREATE INDEX IF NOT EXISTS idx_completed_sessions_analysis 
    ON neoquest.game_sessions(game_id, final_score, end_time);
    
    -- Failed uploads for retry processing (simplified)
    CREATE INDEX IF NOT EXISTS idx_failed_uploads_retry 
    ON neoquest.upload_queue(created_at, retry_count) 
    WHERE status = 'failed';
    
    -- Recent player activity (removed CURRENT_TIMESTAMP function)
    CREATE INDEX IF NOT EXISTS idx_recent_player_activity 
    ON neoquest.players(game_id, registered_at);
    
    -- High-accuracy GPS points (removed accuracy function check)
    CREATE INDEX IF NOT EXISTS idx_accurate_gps_tracks 
    ON neoquest.gps_tracks(session_id, timestamp, latitude, longitude);
    
    -- -----------------------------------------------
    -- JSONB Indexes for Game State & Config
    -- -----------------------------------------------
    
    -- Game state GIN indexes for complex queries
    CREATE INDEX IF NOT EXISTS idx_game_sessions_state_gin 
    ON neoquest.game_sessions USING GIN (game_state);
    
    CREATE INDEX IF NOT EXISTS idx_game_config_gin 
    ON neoquest.games USING GIN (game_config);
    
    CREATE INDEX IF NOT EXISTS idx_puzzle_config_gin 
    ON neoquest.puzzles USING GIN (puzzle_config);
    
    CREATE INDEX IF NOT EXISTS idx_checkpoint_config_gin 
    ON neoquest.checkpoints USING GIN (checkpoint_config);
    
    -- Specific JSONB path indexes for frequent queries
    CREATE INDEX IF NOT EXISTS idx_game_state_current_points 
    ON neoquest.game_sessions USING BTREE ((game_state->>'current_points'));
    
    CREATE INDEX IF NOT EXISTS idx_game_state_checkpoint 
    ON neoquest.game_sessions USING BTREE ((game_state->>'current_checkpoint_id'));
    
    CREATE INDEX IF NOT EXISTS idx_puzzle_config_correct_answer 
    ON neoquest.puzzles USING BTREE ((puzzle_config->>'correct_answer'));
  `);
};

exports.down = function(db) {
  return db.runSql(`
    SET search_path TO neoquest, public;
    
    -- -----------------------------------------------
    -- Drop JSONB Indexes
    -- -----------------------------------------------
    DROP INDEX IF EXISTS neoquest.idx_puzzle_config_correct_answer;
    DROP INDEX IF EXISTS neoquest.idx_game_state_checkpoint;
    DROP INDEX IF EXISTS neoquest.idx_game_state_current_points;
    DROP INDEX IF EXISTS neoquest.idx_checkpoint_config_gin;
    DROP INDEX IF EXISTS neoquest.idx_puzzle_config_gin;
    DROP INDEX IF EXISTS neoquest.idx_game_config_gin;
    DROP INDEX IF EXISTS neoquest.idx_game_sessions_state_gin;
    
    -- -----------------------------------------------
    -- Drop Partial Indexes
    -- -----------------------------------------------
    DROP INDEX IF EXISTS neoquest.idx_accurate_gps_tracks;
    DROP INDEX IF EXISTS neoquest.idx_recent_player_activity;
    DROP INDEX IF EXISTS neoquest.idx_failed_uploads_retry;
    DROP INDEX IF EXISTS neoquest.idx_completed_sessions_analysis;
    DROP INDEX IF EXISTS neoquest.idx_active_sessions_performance;
    
    -- -----------------------------------------------
    -- Drop Analytics Indexes
    -- -----------------------------------------------
    DROP INDEX IF EXISTS neoquest.idx_game_statistics_metrics;
    DROP INDEX IF EXISTS neoquest.idx_game_statistics_date_range;
    DROP INDEX IF EXISTS neoquest.idx_leaderboards_daily;
    DROP INDEX IF EXISTS neoquest.idx_leaderboards_player_performance;
    DROP INDEX IF EXISTS neoquest.idx_leaderboards_score_time;
    DROP INDEX IF EXISTS neoquest.idx_leaderboards_game_rank;
    
    -- -----------------------------------------------
    -- Drop Admin Indexes
    -- -----------------------------------------------
    DROP INDEX IF EXISTS neoquest.idx_esp32_commands_retry;
    DROP INDEX IF EXISTS neoquest.idx_esp32_commands_target_time;
    DROP INDEX IF EXISTS neoquest.idx_esp32_commands_game_status;
    DROP INDEX IF EXISTS neoquest.idx_game_config_type;
    DROP INDEX IF EXISTS neoquest.idx_game_config_key;
    
    -- -----------------------------------------------
    -- Drop Media Indexes
    -- -----------------------------------------------
    DROP INDEX IF EXISTS neoquest.idx_media_files_type_size;
    DROP INDEX IF EXISTS neoquest.idx_media_files_uploader_time;
    DROP INDEX IF EXISTS neoquest.idx_photo_uploads_puzzle;
    DROP INDEX IF EXISTS neoquest.idx_photo_uploads_location_time;
    DROP INDEX IF EXISTS neoquest.idx_photo_uploads_session_checkpoint;
    DROP INDEX IF EXISTS neoquest.idx_upload_queue_retry;
    DROP INDEX IF EXISTS neoquest.idx_upload_queue_priority_status;
    DROP INDEX IF EXISTS neoquest.idx_upload_queue_session_type;
    
    -- -----------------------------------------------
    -- Drop Hints Indexes
    -- -----------------------------------------------
    DROP INDEX IF EXISTS neoquest.idx_hint_usage_hint_frequency;
    DROP INDEX IF EXISTS neoquest.idx_hint_usage_player_cost;
    DROP INDEX IF EXISTS neoquest.idx_hint_usage_session;
    DROP INDEX IF EXISTS neoquest.idx_hints_cost;
    DROP INDEX IF EXISTS neoquest.idx_hints_unlock_condition;
    DROP INDEX IF EXISTS neoquest.idx_hints_puzzle_order;
    DROP INDEX IF EXISTS neoquest.idx_hints_game_active;
    
    -- -----------------------------------------------
    -- Drop Puzzle Indexes
    -- -----------------------------------------------
    DROP INDEX IF EXISTS neoquest.idx_puzzle_attempts_performance;
    DROP INDEX IF EXISTS neoquest.idx_puzzle_attempts_correct;
    DROP INDEX IF EXISTS neoquest.idx_puzzle_attempts_player_time;
    DROP INDEX IF EXISTS neoquest.idx_puzzle_attempts_session_puzzle;
    DROP INDEX IF EXISTS neoquest.idx_puzzles_unlock_condition;
    DROP INDEX IF EXISTS neoquest.idx_puzzles_type_difficulty;
    DROP INDEX IF EXISTS neoquest.idx_puzzles_checkpoint;
    DROP INDEX IF EXISTS neoquest.idx_puzzles_game_active_order;
    
    -- -----------------------------------------------
    -- Drop GPS & Location Indexes
    -- -----------------------------------------------
    DROP INDEX IF EXISTS neoquest.idx_gps_tracks_accuracy;
    DROP INDEX IF EXISTS neoquest.idx_gps_tracks_location_time;
    DROP INDEX IF EXISTS neoquest.idx_gps_tracks_game_timestamp;
    DROP INDEX IF EXISTS neoquest.idx_gps_tracks_session_timestamp;
    DROP INDEX IF EXISTS neoquest.idx_checkpoint_visits_location;
    DROP INDEX IF EXISTS neoquest.idx_checkpoint_visits_verification;
    DROP INDEX IF EXISTS neoquest.idx_checkpoint_visits_session_time;
    DROP INDEX IF EXISTS neoquest.idx_checkpoints_required;
    DROP INDEX IF EXISTS neoquest.idx_checkpoints_location;
    DROP INDEX IF EXISTS neoquest.idx_checkpoints_game_type_order;
    
    -- -----------------------------------------------
    -- Drop Session Indexes
    -- -----------------------------------------------
    DROP INDEX IF EXISTS neoquest.idx_player_games_completion;
    DROP INDEX IF EXISTS neoquest.idx_player_games_assignment;
    DROP INDEX IF EXISTS neoquest.idx_game_sessions_active;
    DROP INDEX IF EXISTS neoquest.idx_game_sessions_start_time;
    -- session_token index removed (UNIQUE constraint creates automatic index)
    DROP INDEX IF EXISTS neoquest.idx_game_sessions_game_status;
    DROP INDEX IF EXISTS neoquest.idx_game_sessions_player_status;
    
    -- -----------------------------------------------
    -- Drop Core Indexes
    -- -----------------------------------------------
    DROP INDEX IF EXISTS neoquest.idx_players_registration_time;
    DROP INDEX IF EXISTS neoquest.idx_players_game_completed;
    DROP INDEX IF EXISTS neoquest.idx_players_token_active;
    DROP INDEX IF EXISTS neoquest.idx_games_complexity_active;
    DROP INDEX IF EXISTS neoquest.idx_games_active_type;
    
    -- -----------------------------------------------
    -- Drop Legacy Indexes
    -- -----------------------------------------------
    DROP INDEX IF EXISTS neoquest.idx_quiz_results_player_puzzle;
    DROP INDEX IF EXISTS neoquest.idx_checkpoints_game_order;
    DROP INDEX IF EXISTS neoquest.idx_puzzles_game_order;
    DROP INDEX IF EXISTS neoquest.idx_checkpoint_visits_player_checkpoint;
    DROP INDEX IF EXISTS neoquest.idx_upload_queue_status_position;
    DROP INDEX IF EXISTS neoquest.idx_gps_tracks_player_timestamp;
  `);
};

exports._meta = {
  "version": 1
}