'use strict';

/**
 * Spieler werden zuerst ohne Token angelegt (POST /api/auth/create-player)
 * und erst danach per QR-Scan mit Token und Spiel verknuepft (POST /api/auth/link-token).
 *
 * Die Init-Migration definiert diese Spalten inzwischen als optional. Datenbanken,
 * die mit einer aelteren Fassung angelegt wurden, haben aber noch NOT NULL darauf -
 * dann schlaegt create-player mit "null value in column token" fehl.
 * Diese Migration gleicht das an. Sie ist idempotent: Ist eine Spalte schon optional,
 * passiert nichts.
 */

var dbm;
var type;
var seed;

exports.setup = function (options, seedLink) {
  dbm = options.dbmigrate;
  type = dbm.dataType;
  seed = seedLink;
};

exports.up = function (db) {
  return db.runSql(`
    ALTER TABLE neoquest.players ALTER COLUMN token           DROP NOT NULL;
    ALTER TABLE neoquest.players ALTER COLUMN game_id         DROP NOT NULL;
    ALTER TABLE neoquest.players ALTER COLUMN game_title      DROP NOT NULL;
    ALTER TABLE neoquest.players ALTER COLUMN qr_code_content DROP NOT NULL;
  `);
};

exports.down = function (db) {
  // Bewusst leer: NOT NULL wieder zu setzen wuerde an Spielern ohne Token scheitern.
  return Promise.resolve();
};

exports._meta = {
  version: 1
};
