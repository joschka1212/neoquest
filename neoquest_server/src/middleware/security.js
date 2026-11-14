/**
 * Security Middleware
 * IP access control and other security measures
 */

const logger = require('../utils/logger');

/**
 * Validate IP access for LAN-only operation
 * @param {Object} req Express request object
 * @param {Object} res Express response object  
 * @param {Function} next Express next function
 */
function validateIPAccess(req, res, next) {
  // Get client IP address
  const clientIP = req.ip || 
                   req.connection.remoteAddress || 
                   req.socket.remoteAddress ||
                   (req.connection.socket ? req.connection.socket.remoteAddress : null);

  // Clean IPv6-mapped IPv4 addresses
  const cleanIP = clientIP ? clientIP.replace('::ffff:', '') : 'unknown';
  
  // Get allowed IP ranges from environment
  const allowedRanges = process.env.ALLOWED_IP_RANGES ? 
    process.env.ALLOWED_IP_RANGES.split(',').map(range => range.trim()) : 
    ['192.168.1.0/24', '10.0.0.0/24', '127.0.0.1/32'];

  // Check if IP is allowed
  const isAllowed = isIPInRanges(cleanIP, allowedRanges);

  if (!isAllowed) {
    logger.security('Unauthorized IP access attempt', {
      ip: cleanIP,
      userAgent: req.get('User-Agent'),
      url: req.originalUrl,
      method: req.method
    });

    return res.status(403).json({
      error: 'Access denied',
      message: 'This server is only accessible from local network',
      timestamp: new Date().toISOString()
    });
  }

  // Log successful access
  logger.debug('IP access granted', { ip: cleanIP });
  next();
}

/**
 * Check if IP address is within allowed ranges
 * @param {string} ip IP address to check
 * @param {Array} ranges Array of CIDR ranges
 * @returns {boolean} True if IP is allowed
 */
function isIPInRanges(ip, ranges) {
  // Allow localhost variations
  if (ip === '127.0.0.1' || ip === 'localhost' || ip === '::1') {
    return true;
  }

  // Check each range
  for (const range of ranges) {
    if (isIPInRange(ip, range)) {
      return true;
    }
  }

  return false;
}

/**
 * Check if IP is in specific CIDR range
 * @param {string} ip IP address
 * @param {string} range CIDR range (e.g., '192.168.1.0/24')
 * @returns {boolean} True if IP is in range
 */
function isIPInRange(ip, range) {
  try {
    // Handle single IP (no subnet)
    if (!range.includes('/')) {
      return ip === range;
    }

    const [rangeIP, subnetBits] = range.split('/');
    const subnetMask = (0xffffffff << (32 - parseInt(subnetBits))) >>> 0;
    
    const ipInt = ipToInt(ip);
    const rangeInt = ipToInt(rangeIP);
    
    return (ipInt & subnetMask) === (rangeInt & subnetMask);
    
  } catch (error) {
    logger.warn('IP range check failed', { ip, range, error: error.message });
    return false;
  }
}

/**
 * Convert IP address to integer
 * @param {string} ip IP address string
 * @returns {number} IP as integer
 */
function ipToInt(ip) {
  return ip.split('.').reduce((int, octet) => (int << 8) + parseInt(octet, 10), 0) >>> 0;
}

/**
 * Rate limiting by IP
 * Simple in-memory rate limiter
 */
const requestCounts = new Map();
const RATE_LIMIT_WINDOW = 15 * 60 * 1000; // 15 minutes
const RATE_LIMIT_MAX = 100; // requests per window

function simpleRateLimit(req, res, next) {
  const clientIP = req.ip || req.connection.remoteAddress || 'unknown';
  const now = Date.now();
  
  // Clean old entries
  for (const [ip, data] of requestCounts.entries()) {
    if (now - data.firstRequest > RATE_LIMIT_WINDOW) {
      requestCounts.delete(ip);
    }
  }
  
  // Get or create request data for this IP
  let requestData = requestCounts.get(clientIP);
  if (!requestData) {
    requestData = { count: 0, firstRequest: now };
    requestCounts.set(clientIP, requestData);
  }
  
  // Reset if window expired
  if (now - requestData.firstRequest > RATE_LIMIT_WINDOW) {
    requestData.count = 0;
    requestData.firstRequest = now;
  }
  
  // Increment count
  requestData.count++;
  
  // Check limit
  if (requestData.count > RATE_LIMIT_MAX) {
    logger.security('Rate limit exceeded', {
      ip: clientIP,
      count: requestData.count,
      limit: RATE_LIMIT_MAX
    });
    
    return res.status(429).json({
      error: 'Too Many Requests',
      message: `Rate limit exceeded. Try again in ${Math.ceil((RATE_LIMIT_WINDOW - (now - requestData.firstRequest)) / 60000)} minutes.`,
      retryAfter: Math.ceil((RATE_LIMIT_WINDOW - (now - requestData.firstRequest)) / 1000)
    });
  }
  
  // Add rate limit headers
  res.set({
    'X-RateLimit-Limit': RATE_LIMIT_MAX,
    'X-RateLimit-Remaining': Math.max(0, RATE_LIMIT_MAX - requestData.count),
    'X-RateLimit-Reset': new Date(requestData.firstRequest + RATE_LIMIT_WINDOW).toISOString()
  });
  
  next();
}

module.exports = {
  validateIPAccess,
  simpleRateLimit,
  isIPInRanges,
  isIPInRange
};