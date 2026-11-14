/**
 * Logger Utility
 * Simple but effective logging for NeoQuest server
 */

const fs = require('fs');
const path = require('path');

// Log levels
const LOG_LEVELS = {
  error: 0,
  warn: 1,
  info: 2,
  debug: 3
};

const COLORS = {
  error: '\x1b[31m',   // Red
  warn: '\x1b[33m',    // Yellow  
  info: '\x1b[36m',    // Cyan
  debug: '\x1b[37m',   // White
  reset: '\x1b[0m'     // Reset
};

class Logger {
  constructor() {
    this.level = LOG_LEVELS[process.env.LOG_LEVEL] || LOG_LEVELS.info;
    this.logFile = process.env.LOG_FILE;
    
    // Ensure log directory exists
    if (this.logFile) {
      const logDir = path.dirname(this.logFile);
      if (!fs.existsSync(logDir)) {
        fs.mkdirSync(logDir, { recursive: true });
      }
    }
  }

  formatMessage(level, message, meta = {}) {
    const timestamp = new Date().toISOString();
    const pid = process.pid;
    
    // Base log object
    const logObj = {
      timestamp,
      level: level.toUpperCase(),
      pid,
      message: typeof message === 'string' ? message : JSON.stringify(message),
      ...meta
    };

    return logObj;
  }

  writeToFile(logObj) {
    if (!this.logFile) return;
    
    const logLine = JSON.stringify(logObj) + '\n';
    
    fs.appendFile(this.logFile, logLine, (err) => {
      if (err) {
        console.error('Failed to write to log file:', err);
      }
    });
  }

  writeToConsole(level, logObj) {
    const color = COLORS[level] || COLORS.reset;
    const message = logObj.message;
    const meta = { ...logObj };
    delete meta.timestamp;
    delete meta.level;
    delete meta.pid;
    delete meta.message;
    
    // Format console output
    let consoleOutput = `${color}[${logObj.timestamp}] ${logObj.level}:${COLORS.reset} ${message}`;
    
    // Add metadata if present
    if (Object.keys(meta).length > 0) {
      consoleOutput += ` ${JSON.stringify(meta)}`;
    }
    
    // Output to appropriate stream
    if (level === 'error' || level === 'warn') {
      console.error(consoleOutput);
    } else {
      console.log(consoleOutput);
    }
  }

  log(level, message, meta = {}) {
    if (LOG_LEVELS[level] > this.level) {
      return; // Skip if log level is too low
    }

    const logObj = this.formatMessage(level, message, meta);
    
    // Write to console
    this.writeToConsole(level, logObj);
    
    // Write to file if configured
    this.writeToFile(logObj);
  }

  error(message, meta = {}) {
    // Handle Error objects
    if (message instanceof Error) {
      meta = {
        ...meta,
        stack: message.stack,
        name: message.name
      };
      message = message.message;
    }
    
    this.log('error', message, meta);
  }

  warn(message, meta = {}) {
    this.log('warn', message, meta);
  }

  info(message, meta = {}) {
    this.log('info', message, meta);
  }

  debug(message, meta = {}) {
    this.log('debug', message, meta);
  }

  // Convenience method for HTTP request logging
  request(req, res, responseTime) {
    this.info('HTTP Request', {
      method: req.method,
      url: req.originalUrl,
      ip: req.ip || req.connection.remoteAddress,
      userAgent: req.get('User-Agent'),
      statusCode: res.statusCode,
      responseTime: `${responseTime}ms`,
      contentLength: res.get('Content-Length')
    });
  }

  // Database query logging
  dbQuery(query, duration, rowCount, error = null) {
    const meta = {
      duration: `${duration}ms`,
      query: query.substring(0, 100) + (query.length > 100 ? '...' : ''),
      rowCount
    };

    if (error) {
      this.error('Database Query Failed', { ...meta, error: error.message });
    } else {
      this.debug('Database Query', meta);
    }
  }

  // Security event logging
  security(event, details = {}) {
    this.warn('Security Event', {
      event,
      ...details,
      timestamp: new Date().toISOString()
    });
  }
}

// Create singleton instance
const logger = new Logger();

module.exports = logger;