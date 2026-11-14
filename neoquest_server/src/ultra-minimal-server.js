/**
 * DEBUG: Static Files Problem finden
 */

require('dotenv').config();
const express = require('express');
const path = require('path');

const app = express();
const PORT = 3000;

console.log('🔍 Testing static file middleware...');

// Basic middleware
app.use(express.json());

// Test routes
app.get('/', (req, res) => {
  res.json({ message: 'Testing static files' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// HIER könnte das Problem sein - teste static files einzeln:
console.log('📁 Adding static file middleware...');
console.log('Media path:', path.join(__dirname, '../media'));
console.log('Uploads path:', path.join(__dirname, '../uploads'));

try {
  // Test 1: Media directory
  const mediaPath = path.join(__dirname, '../media');
  console.log('📂 Resolved media path:', path.resolve(mediaPath));
  app.use('/media', express.static(mediaPath));
  console.log('✅ Media static middleware added');
} catch (error) {
  console.error('❌ Media static middleware failed:', error);
}

try {
  // Test 2: Uploads directory  
  const uploadsPath = path.join(__dirname, '../uploads');
  console.log('📂 Resolved uploads path:', path.resolve(uploadsPath));
  app.use('/uploads', express.static(uploadsPath));
  console.log('✅ Uploads static middleware added');
} catch (error) {
  console.error('❌ Uploads static middleware failed:', error);
}

// Test: Add single API route
try {
  const authRoutes = require('./routes/auth');
  app.use('/api/auth', authRoutes);
  console.log('✅ Auth routes added');
} catch (error) {
  console.error('❌ Auth routes failed:', error);
}

// ACHTUNG: Wildcard Route zum Schluss - das könnte das Problem sein
console.log('⚠️ Adding wildcard route...');
try {
  app.all('/*catchall', (req, res) => {
    res.status(404).json({
      error: 'Not found',
      path: req.originalUrl
    });
  });
  console.log('✅ Wildcard route added');
} catch (error) {
  console.error('❌ Wildcard route failed:', error);
}

console.log('🚀 Starting server with static files...');

app.listen(PORT, () => {
  console.log('✅ Server running on port 3000');
  console.log('📍 Test endpoints:');
  console.log('   http://localhost:3000/health');
  console.log('   http://localhost:3000/media/');
  console.log('   http://localhost:3000/uploads/');
});

module.exports = app;
