var fs = require('fs');
var _ = require('underscore');
var gulp = require('gulp');
var gutil = require('gulp-util');
var rimraf = require('gulp-rimraf');
var jshint = require('gulp-jshint');
var jscs = require('gulp-jscs');
var rename = require('gulp-rename');
var uglify = require('gulp-uglify');

function exec(cmd, options, cb) {
  'use strict';

  gutil.log('exec:', cmd);
  cb = cb || options;
  require('child_process').exec(cmd, options, function(err, stdout, stderr) {
    gutil.log(stdout, stderr);
    cb(err);
  });
}

gulp.task('version', function(cb) {
  'use strict';

  exec('git describe --always > VERSION', cb);
});

gulp.task('lint-jshint', function() {
  'use strict';

  return gulp.src([ 'jslib/*.js', 'gulpfile.js' ])
    .pipe(jshint())
    .pipe(jshint.reporter('default'))
    .pipe(jshint.reporter('fail'));
});

gulp.task('lint-jscs', function() {
  'use strict';

  return gulp.src([ 'jslib/*.js', 'gulpfile.js' ])
    .pipe(jscs());
});

gulp.task('minify', function()
{
  gulp.src('jslib/locomote.js')
    .pipe(uglify())
    .pipe(rename('locomote.min.js'))
    .pipe(gulp.dest('jslib'))
});

gulp.task('submodule', function(cb) {
  'use strict';

  return exec('git submodule init && git submodule update', cb);
});

gulp.task('build-as3corelib', [ 'submodule' ], function(cb) {
  'use strict';

  if (fs.existsSync('ext/as3corelib/bin/as3corelib.swc')) {
    return cb();
  }

  var options = {
    env: {
      FLEX_HOME: __dirname + '/node_modules/flex-sdk/lib/flex_sdk/'
    }
  };
  exec('ant -f ext/as3corelib/build/build.xml', options, cb);
});

gulp.task('build-locomote', [ 'build-as3corelib', 'version' ], function(cb) {
  'use strict';

  var mxmlcOptions = {
    'use-network': true,
    'static-link-runtime-shared-libraries': true,
    'use-resource-bundle-metadata': true,
    'accessible': false,
    'allow-source-path-overlap': false,
    'target-player': 11.1,
    'locale': 'en_US',
    'output': 'build/Player.swf',
    'debug': true,
    'benchmark': false,
    'verbose-stacktraces': false,
    'strict': true,
    'warnings': true,
    'show-unused-type-selector-warnings': true,
    'show-actionscript-warnings': true,
    'show-binding-warnings': true,
    'show-invalid-css-property-warnings': true,
    'incremental': false,
    'es': false,
    'include-libraries': 'ext/as3corelib/bin/as3corelib.swc'
  };

  var optString = _.reduce(mxmlcOptions, function(memo, value, index) {
    return memo + ' -' + index + '=' + value.toString();
  }, '');

  exec('./node_modules/.bin/mxmlc ' + optString + ' src/Player.as', cb);
});

gulp.task('test', [ 'lint-jshint', 'lint-jscs' ]);

gulp.task('default', [ 'build-as3corelib', 'build-locomote', 'minify' ]);

gulp.task('clean', function() {
  'use strict';

  gulp.src([ 'build/', 'ext/as3corelib/', 'VERSION' ], { read: false })
    .pipe(rimraf({ force: true }));
});
