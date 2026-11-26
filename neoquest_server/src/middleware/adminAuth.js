/**
 * Gemeinsame Admin-Pruefung fuer alle /admin-Endpunkte.
 *
 * Der Schluessel kommt ausschliesslich aus ADMIN_KEY in neoquest_server/.env.
 * Es gibt bewusst keinen eingebauten Ersatzwert: Ist ADMIN_KEY nicht gesetzt,
 * sind die Admin-Endpunkte gesperrt (503), statt offen zu stehen.
 *
 * Der Schluessel kann als Header X-Admin-Key, als admin_key im Body
 * oder als admin_key im Query-String uebergeben werden.
 */

const crypto = require('crypto');
const logger = require('../utils/logger');

function keysMatch(given, expected) {
  const a = Buffer.from(String(given));
  const b = Buffer.from(String(expected));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function requireAdmin(req, res, next) {
  const expected = process.env.ADMIN_KEY;

  if (!expected) {
    logger.error('ADMIN_KEY ist nicht gesetzt - Admin-Endpunkte gesperrt', {
      endpoint: req.originalUrl
    });
    return res.status(503).json({
      success: false,
      error: 'Admin access not configured',
      message: 'ADMIN_KEY is not set in the server .env'
    });
  }

  const given = req.headers['x-admin-key'] ||
                (req.body && req.body.admin_key) ||
                (req.query && req.query.admin_key);

  if (!given || !keysMatch(given, expected)) {
    logger.security('Rejected admin request', {
      endpoint: req.originalUrl,
      method: req.method,
      ip: req.ip
    });
    return res.status(403).json({
      success: false,
      error: 'Admin access required',
      message: 'Provide a valid admin key (header X-Admin-Key, body or query admin_key)'
    });
  }

  logger.info('Admin access granted', {
    endpoint: req.originalUrl,
    method: req.method,
    ip: req.ip
  });

  next();
}

module.exports = { requireAdmin };
