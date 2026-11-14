/**
 * File: ../neoquest_db/migrations/19920214000003-seed-data.js
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
    -- NeoQuest Seed Data - Möllersdorf Focus
    -- Enhanced for new schema while keeping original data
    -- ===============================================
    
    SET search_path TO neoquest, public;
    
    -- -----------------------------------------------
    -- Games - Möllersdorf in different complexity levels
    -- -----------------------------------------------
    
    INSERT INTO neoquest.games (name, description, game_type, complexity_level, game_config, start_audio_path, is_active) VALUES 
    
    -- Original Möllersdorf (Level 1: Simple Race)
    ('Möllersdorf Schatzsuche', 
     'Entdecke die Geheimnisse von Möllersdorf rund um die Münchendorferstrasse', 
     'individual', 
     'simple_race',
     '{
       "scoring": {
         "base_points": 1000,
         "time_bonus": true,
         "time_penalty_per_minute": 5,
         "completion_bonus": 200
       },
       "features": {
         "has_checkpoints": true,
         "has_puzzles": false,
         "has_puzzles": false,
         "has_hints": false,
         "puzzles_unlock_hints": false,
         "hints_cost_points": false,
         "location_based_triggers": false
       },
       "time_limits": {
         "max_game_duration": 3600
       }
     }',
     '/media/audio/start_moellersdorf.mp3', 
     true),
    
    -- Alternative: Wien für Vergleichstests (Level 2: Hint Enhanced)
    ('Wien Alternative Tour', 
     'Alternative Route durch Wien für Vergleichstests', 
     'competitive', 
     'hint_enhanced_race',
     '{
       "scoring": {
         "base_points": 1500,
         "time_bonus": true,
         "time_penalty_per_minute": 3,
         "completion_bonus": 300
       },
       "features": {
         "has_checkpoints": true,
         "has_puzzles": false,
         "has_hints": true,
         "puzzles_unlock_hints": false,
         "hints_cost_points": true,
         "location_based_triggers": false
       },
       "time_limits": {
         "max_game_duration": 7200
       }
     }',
     '/media/audio/start_wien.mp3', 
     true),
    
    -- Enhanced: Traiskirchen Geschichte (Level 3: Multi-Checkpoint)
    ('Traiskirchen Geschichte', 
     'Historische Tour durch Traiskirchen und Möllersdorf', 
     'individual', 
     'multi_checkpoint_adventure',
     '{
       "scoring": {
         "base_points": 2000,
         "time_bonus": false,
         "time_penalty_per_minute": 2,
         "completion_bonus": 500
       },
       "features": {
         "has_checkpoints": true,
         "has_puzzles": true,
         "has_hints": true,
         "puzzles_unlock_hints": false,
         "hints_cost_points": true,
         "location_based_triggers": true
       },
       "time_limits": {
         "max_game_duration": 4500
       }
     }',
     '/media/audio/start_traiskirchen.mp3', 
     true);
    
    -- -----------------------------------------------
    -- Checkpoints for Möllersdorf (Game ID 1)
    -- -----------------------------------------------
    
    INSERT INTO neoquest.checkpoints (game_id, checkpoint_order, name, latitude, longitude, radius, checkpoint_type, qr_code_content, is_required, checkpoint_config, description) VALUES 
    (1, 1, 'Start Münchendorferstrasse 12', 48.025800, 16.305100, 15, 'start', 'CHECKPOINT_MOELL_001', true,
     '{
       "point_bonus": 0, 
       "media_files": ["moellersdorf001_start.mp3"], 
       "min_stay_duration": 30,
       "welcome_message": "Willkommen zur Möllersdorf Schatzsuche!"
     }', 
     'Zentrum Möllersdorf - Münchendorferstrasse 12'),
    
    (1, 2, 'Brücke über Mühlbach', 48.027200, 16.304500, 15, 'intermediate', 'CHECKPOINT_MOELL_002', true,
     '{
       "point_bonus": 50, 
       "media_files": ["moellersdorf002_bridge.jpg", "muehlbach_info.mp3"], 
       "min_stay_duration": 60,
       "photo_required": true,
       "photo_instructions": "Mache ein Foto von der Brücke und dem Mühlbach"
     }', 
     'Brücke über den Mühlbach bei Brückengasse'),
    
    (1, 3, 'Bahnschranken Münchendorferstrasse', 48.024500, 16.306800, 15, 'intermediate', 'CHECKPOINT_MOELL_003', true,
     '{
       "point_bonus": 75, 
       "media_files": ["moellersdorf003_railway.mp4"], 
       "min_stay_duration": 45,
       "photo_required": true,
       "safety_warning": "Achtung: Nicht auf die Gleise! Sicherheitsabstand beachten."
     }', 
     'Bahnschranken an der Münchendorferstrasse'),
    
    (1, 4, 'Bahnhaltestelle Möllersdorf Aspangbahn', 48.023100, 16.308200, 20, 'finish', 'CHECKPOINT_MOELL_004', true,
     '{
       "point_bonus": 200, 
       "media_files": ["moellersdorf004_finish.mp3", "victory_moell.jpg"], 
       "celebration": true,
       "min_stay_duration": 90,
       "victory_photo_required": true,
       "completion_message": "Herzlichen Glückwunsch! Du hast die Möllersdorf Schatzsuche erfolgreich abgeschlossen!"
     }', 
     'Bahnhaltestelle Möllersdorf der Aspangbahn');
    
    -- -----------------------------------------------
    -- Checkpoints for Wien Alternative (Game ID 2)
    -- -----------------------------------------------
    
    INSERT INTO neoquest.checkpoints (game_id, checkpoint_order, name, latitude, longitude, radius, checkpoint_type, qr_code_content, checkpoint_config, description) VALUES 
    (2, 1, 'Stephansdom', 48.208354, 16.373819, 15, 'start', 'CHECKPOINT_WIEN_001', 
     '{"point_bonus": 0, "available_hints": ["wien_hint_001", "wien_hint_002"], "media_files": ["stephansdom_intro.mp4"]}', 
     'Der berühmte Wiener Dom'),
    (2, 2, 'Graben', 48.208176, 16.368330, 15, 'intermediate', 'CHECKPOINT_WIEN_002', 
     '{"point_bonus": 100, "available_hints": ["wien_hint_003"], "media_files": ["graben_history.jpg"]}', 
     'Prachtstraße im Herzen Wiens'),
    (2, 3, 'Hofburg', 48.206649, 16.363998, 15, 'intermediate', 'CHECKPOINT_WIEN_003', 
     '{"point_bonus": 150, "available_hints": ["wien_hint_004"], "media_files": ["hofburg_tour.mp4"]}', 
     'Ehemalige Kaiserresidenz'),
    (2, 4, 'Naschmarkt', 48.198314, 16.364816, 15, 'finish', 'CHECKPOINT_WIEN_004', 
     '{"point_bonus": 300, "celebration": true, "media_files": ["naschmarkt_finish.mp3"]}', 
     'Berühmter Wiener Markt');
    
    -- -----------------------------------------------
    -- Checkpoints for Traiskirchen Geschichte (Game ID 3)
    -- -----------------------------------------------
    
    INSERT INTO neoquest.checkpoints (game_id, checkpoint_order, name, latitude, longitude, radius, checkpoint_type, qr_code_content, checkpoint_config, description) VALUES 
    (3, 1, 'Kammgarnsaal Möllersdorf', 48.026500, 16.303800, 20, 'start', 'CHECKPOINT_TRAIS_001', 
     '{"point_bonus": 0, "puzzles": ["trais_puzzle001"], "media_files": ["kammgarn_history.mp4"], "min_stay_duration": 120}', 
     'Historischer Kammgarnsaal mit Museum'),
    (3, 2, 'Schloss Möllersdorf', 48.028200, 16.302900, 20, 'intermediate', 'CHECKPOINT_TRAIS_002', 
     '{"point_bonus": 200, "puzzles": ["trais_puzzle002"], "available_hints": ["trais_hint_002"], "media_files": ["schloss_tour.jpg"], "min_stay_duration": 90}', 
     'Ehemaliges Schloss, heute Kindergarten'),
    (3, 3, 'Mühlbach Wasserkraft', 48.027800, 16.304200, 20, 'finish', 'CHECKPOINT_TRAIS_003', 
     '{"point_bonus": 400, "celebration": true, "media_files": ["wasserkraft_finish.mp3"], "min_stay_duration": 60}', 
     'Historische Wasserkraftnutzung am Mühlbach');
    
    -- -----------------------------------------------
    -- Puzzles for Level 3 Game (Traiskirchen Geschichte)
    -- -----------------------------------------------
    
    -- Modern Format Puzzles for Game 3 (Traiskirchen Geschichte)
    INSERT INTO neoquest.puzzles (game_id, puzzle_id, checkpoint_id, title, question, puzzle_type, puzzle_config, points, max_attempts, unlock_condition) VALUES 
    (3, 'trais_puzzle001', 1, 'Möllersdorf Herren', 'Welche Adelsfamilie war Grundherr in Möllersdorf?', 'multiple_choice', 
     '{
       "correct_answer": "A",
       "options": [
         {"id": "A", "text": "Herren von Möllersdorf"},
         {"id": "B", "text": "Herren von Traiskirchen"},
         {"id": "C", "text": "Herren von Baden"},
         {"id": "D", "text": "Herren von Vöslau"}
       ],
       "randomize_order": true
     }', 100, 3, 'location_based'),
    
    (3, 'trais_puzzle002', 2, 'Türkenbelagerung Jahr', 'In welchem Jahr wurde Möllersdorf durch die Türken zerstört? (±5 Jahre Toleranz)', 'integer', 
     '{
       "correct_answer": 1683,
       "tolerance": 5,
       "min_value": 1650,
       "max_value": 1720
     }', 150, 2, 'location_based');
    
    -- -----------------------------------------------
    -- Hints System (Level 2 & 3 Games)
    -- -----------------------------------------------
    
    -- Hints for Game 2 (Wien Alternative)
    INSERT INTO neoquest.hints (game_id, hint_id, title, hint_text, media_file, point_cost, unlock_condition, hint_order) VALUES 
    (2, 'wien_hint_001', 'Stephansdom Navigation', 'Der Dom ist das höchste Gebäude weit und breit - folge dem Turm!', 'wien_hint001_audio.mp3', 20, 'immediate', 1),
    (2, 'wien_hint_002', 'Stephansdom Details', 'Schau dir die Details am Hauptportal genau an - dort findest du Jahreszahlen.', 'wien_hint002_photo.jpg', 30, 'immediate', 2),
    (2, 'wien_hint_003', 'Graben Richtung', 'Vom Stephansdom aus gehe westlich - der Graben verbindet direkt.', 'wien_hint003_map.jpg', 25, 'immediate', 1),
    (2, 'wien_hint_004', 'Hofburg Eingang', 'Suche den Haupteingang bei der Michaelerkuppel - nicht alle Eingänge sind offen.', 'wien_hint004_entrance.mp4', 35, 'immediate', 1);
    
    -- Hints for Game 3 (Traiskirchen)
    INSERT INTO neoquest.hints (game_id, hint_id, puzzle_id, title, hint_text, media_file, point_cost, unlock_condition, hint_order) VALUES 
    (3, 'trais_hint_001', 'trais_puzzle001', 'Adelsfamilie Hinweis', 'Der Name der Familie ist direkt mit dem Ortsnamen verbunden - sehr logisch!', 'trais_hint001_nobility.mp3', 40, 'immediate', 1),
    (3, 'trais_hint_002', 'trais_puzzle002', 'Türkenbelagerung Hinweis', 'Es war die zweite große Belagerung Wiens - ein sehr bekanntes historisches Datum.', 'trais_hint002_history.mp4', 50, 'immediate', 1);
    
    -- -----------------------------------------------
    -- Game Configuration (Enhanced)
    -- -----------------------------------------------
    
    INSERT INTO neoquest.game_config (game_id, config_key, config_value, config_type, description) VALUES 
    -- Game 1: Möllersdorf Schatzsuche
    (1, 'max_completion_time', '3600', 'number', '1 Stunde für Möllersdorf Schatzsuche'),
    (1, 'gps_tracking_interval', '30', 'number', '30 Sekunden GPS-Tracking'),
    (1, 'checkpoint_radius', '15', 'number', '15 Meter Checkpoint-Radius'),
    (1, 'difficulty_level', 'medium', 'string', 'Mittlere Schwierigkeit'),
    (1, 'photo_required', 'true', 'boolean', 'Fotos an Checkpoints erforderlich'),
    (1, 'offline_mode', 'true', 'boolean', 'Offline-Modus verfügbar'),
    
    -- Game 2: Wien Alternative Tour
    (2, 'max_completion_time', '7200', 'number', '2 Stunden für Wien Tour'),
    (2, 'gps_tracking_interval', '30', 'number', '30 Sekunden GPS-Tracking'),
    (2, 'checkpoint_radius', '15', 'number', '15 Meter Checkpoint-Radius'),
    (2, 'difficulty_level', 'easy', 'string', 'Einfache Schwierigkeit'),
    (2, 'hints_available', 'true', 'boolean', 'Hinweise verfügbar'),
    (2, 'max_hint_cost', '100', 'number', 'Maximale Hinweis-Kosten'),
    
    -- Game 3: Traiskirchen Geschichte
    (3, 'max_completion_time', '4500', 'number', '1.25 Stunden für Traiskirchen Geschichte'),
    (3, 'gps_tracking_interval', '30', 'number', '30 Sekunden GPS-Tracking'),
    (3, 'checkpoint_radius', '20', 'number', '20 Meter Checkpoint-Radius (historische Stätten)'),
    (3, 'difficulty_level', 'hard', 'string', 'Schwere Schwierigkeit'),
    (3, 'puzzles_required', 'true', 'boolean', 'Rätsel müssen gelöst werden'),
    (3, 'educational_mode', 'true', 'boolean', 'Bildungsmodus aktiviert');
    `);
};

exports.down = function(db) {
  return db.runSql(`
    SET search_path TO neoquest, public;
    
    -- Alle Test-Daten löschen (in umgekehrter Reihenfolge wegen FK)
    DELETE FROM neoquest.gps_tracks;
    DELETE FROM neoquest.game_config;
    DELETE FROM neoquest.player_games;
    DELETE FROM neoquest.game_sessions;
    DELETE FROM neoquest.hints;
    DELETE FROM neoquest.puzzles;
    DELETE FROM neoquest.checkpoints;
    DELETE FROM neoquest.players;
    DELETE FROM neoquest.games;
  `);
};

exports._meta = {
  "version": 1
};