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
    SET search_path TO neoquest, public;
    
    -- Remove existing test players that use old token format
    DELETE FROM neoquest.player_games WHERE player_id IN (
      SELECT id FROM neoquest.players WHERE token LIKE 'QR_TOKEN_%'
    );
    DELETE FROM neoquest.players WHERE token LIKE 'QR_TOKEN_%';
    
    -- Add constraint for unique tokens per game
    -- This allows same token ID for different games if needed
    ALTER TABLE neoquest.players 
    ADD CONSTRAINT unique_token_per_game UNIQUE(token, game_id);
    
    -- Add index for better token lookup performance
    CREATE INDEX IF NOT EXISTS idx_players_token_game 
    ON neoquest.players(token, game_id);
    
    -- Update comments to reflect new token usage
    COMMENT ON COLUMN neoquest.players.token IS 'Scanned token ID (e.g. ABC123) from QR code, unique per game';
    COMMENT ON COLUMN neoquest.players.qr_code_content IS 'Full QR code content (e.g. NEOQUEST:ABC123:gamename)';
    
  `);
};

exports.down = function(db) {
  return db.runSql(`
    SET search_path TO neoquest, public;
    
    -- Drop the constraint and index
    ALTER TABLE neoquest.players DROP CONSTRAINT IF EXISTS unique_token_per_game;
    DROP INDEX IF EXISTS neoquest.idx_players_token_game;
    
    -- Restore old token format if needed (optional)
    UPDATE neoquest.players 
    SET token = 'QR_TOKEN_' || token 
    WHERE NOT token LIKE 'QR_TOKEN_%';
    
  `);
};

exports._meta = {
  "version": 1
};