var fs = require('fs');
var _ = require('underscore');
var gulp = require('gulp');
var gutil = require('gulp-util');
var rimraf = require('gulp-rimraf');
var jshint = require('gulp-jshint');
var jscs = require('gulp-jscs');
var rename = require('gulp-rename');
var uglify = require('gulp-uglify');
var git = require('gulp-git');
var bump = require('gulp-bump');
var argv = require('yargs').argv;

function exec(cmd, options, cb) {
  'use strict';

  gutil.log('exec:', cmd);
  cb = cb || options;
  require('child_process').exec(cmd, options, function(err, stdout, stderr) {
    gutil.log(stdout, stderr);
    cb(err);
  });
}

function build(cb) {
  'use strict';

  var mxmlcOptions = {
    'use-network': true,
    'static-link-runtime-shared-libraries': true,
    'use-resource-bundle-metadata': true,
    'accessible': false,
    'allow-source-path-overlap': false,
    'target-player': 11.1,
    'locale': 'en_US',
    'output': 'dist/Player.swf',
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
}

gulp.task('lint-jshint', function() {
  'use strict';

  return gulp.src([ 'jslib/locomote.js', 'gulpfile.js' ])
    .pipe(jshint())
    .pipe(jshint.reporter('default'))
    .pipe(jshint.reporter('fail'));
});

gulp.task('lint-jscs', function() {
  'use strict';

  return gulp.src([ 'jslib/locomote.js', 'gulpfile.js' ])
    .pipe(jscs());
});

gulp.task('minify', function(cb)
{
  'use strict';

  return gulp.src('jslib/locomote.js')
    .pipe(uglify())
    .pipe(rename('locomote.min.js'))
    .pipe(gulp.dest('dist'));
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

gulp.task('build-locomote', [ 'build-as3corelib' ], function(cb) {
  'use strict';

  build(cb);
});

gulp.task('build-locomote-version', [ 'build-as3corelib', 'version-file' ], function(cb) {
  'use strict';

  build(cb);
});

gulp.task('version', function(cb) {
  'use strict';

  return gulp.src('package.json')
    .pipe(bump({ type:argv.ver }))
    .pipe(gulp.dest(''));
});

gulp.task('version-file', [ 'version' ], function() {
  'use strict';

  var pkg = require('./package.json');
  var fs = require('fs');
  fs.writeFile('VERSION', pkg.version);
});

gulp.task('commit-release', [ 'build-locomote-version', 'minify' ], function(cb) {
  'use strict';

  var pkg = require('./package.json');

  return gulp.src([ 'package.json', 'VERSION', 'dist/locomote.min.js', 'dist/Player.swf' ])
    .pipe(git.add())
    .pipe(git.commit('Committed release, version ' + pkg.version + '.'));
});

gulp.task('tag-release', [ 'commit-release' ], function() {
  'use strict';

  var pkg = require('./package.json');

  git.tag('v' + pkg.version, 'Version message', function (err) {
    if (err) {
      throw err;
    }
  });
});

gulp.task('test', [ 'lint-jshint', 'lint-jscs' ]);

gulp.task('default', [ 'build-as3corelib', 'build-locomote', 'minify' ]);

gulp.task('release', [ 'tag-release' ]);

gulp.task('clean', function() {
  'use strict';

  gulp.src([ 'dist/', 'ext/as3corelib/', 'VERSION' ], { read: false })
    .pipe(rimraf({ force: true }));
});
