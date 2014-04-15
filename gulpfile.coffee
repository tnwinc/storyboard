gulp = require 'gulp'
gutil = require 'gulp-util'
through = require 'through2'
es = require 'event-stream'

watch = require 'gulp-watch'
plumber = require 'gulp-plumber'
coffee = require 'gulp-coffee'
sass = require 'gulp-sass'

emberHandlebars = require './lib/gulp-ember-handlebars'
buildIndex = require './lib/gulp-build-index'
order = require './lib/gulp-order'
config = require './config.json'
server = require './server'
deploy = require './lib/deploy'

uglify = require 'gulp-uglify'
minifyCss = require 'gulp-minify-css'
concat = require 'gulp-concat'
rename = require 'gulp-rename'
clean = require 'gulp-clean'


# Dev

gulp.task 'devIndex', ->
  gulp.src('src/index.hbs')
    .pipe(buildIndex.dev(config.scripts, ['stylesheets/all.css']))
    .pipe(gulp.dest('./_dev/'))

gulp.task 'devCopy', ->
  gulp.src('src/fonts/**/*').pipe(gulp.dest('./_dev/fonts/'))
  gulp.src('src/images/**/*').pipe(gulp.dest('./_dev/images/'))
  gulp.src('src/scripts/lib/*').pipe(gulp.dest('./_dev/scripts/lib/'))

gulp.task 'watchCoffee', ->
  watchCoffee = watch glob: 'src/scripts/**/*.coffee'
  watchCoffee
    .pipe(plumber())
    .pipe(coffee().on('error', gutil.log))
    .pipe(gulp.dest('./_dev/scripts/'))

  watchCoffee.gaze.on 'all', (event)->
    if event is 'added' or event is 'deleted'
      gulp.run 'devIndex'

gulp.task 'watchHandlebars', ->
  watch(glob: 'src/scripts/**/*.hbs')
    .pipe(plumber())
    .pipe(emberHandlebars().on('error', gutil.log))
    .pipe(gulp.dest('./_dev/scripts/'))

gulp.task 'watchSass', ->
  watch glob: 'src/stylesheets/*.scss', ->
    gulp.src('src/stylesheets/!(_)*.scss')
      .pipe(sass())
      .pipe(gulp.dest('./_dev/stylesheets/'))

gulp.task 'watch', ['watchCoffee', 'watchHandlebars', 'watchSass']

gulp.task 'devServer', -> server '_dev', 8080

gulp.task 'dev', ['devIndex', 'devCopy', 'watch', 'devServer']


# Prod

cacheBuster = ''

gulp.task 'buildCopy', ['cleanBuild'], ->
  gulp.src('src/fonts/**/*').pipe(gulp.dest('./_build/fonts/'))
  gulp.src('src/images/**/*').pipe(gulp.dest('./_build/images/'))

gulp.task 'buildJs', ['buildCopy'], ->
  cacheBuster = (new Date()).valueOf()
  getJs = gulp.src('src/scripts/lib/*.js')
  buildCoffee = gulp.src('src/scripts/**/*.coffee')
    .pipe(coffee().on('error', gutil.log))
  buildHbs = gulp.src('src/scripts/**/*.hbs')
    .pipe(emberHandlebars().on('error', gutil.log))

  es.concat(getJs, buildCoffee, buildHbs)
    .pipe(order(config.scripts))
    .pipe(uglify())
    .pipe(concat("all-#{cacheBuster}.js"))
    .pipe(gulp.dest('./_build/scripts/'))

gulp.task 'buildSass', ['buildJs'], ->
  gulp.src('src/stylesheets/!(_)*.scss')
    .pipe(sass())
    .pipe(minifyCss())
    .pipe(rename("all-#{cacheBuster}.css"))
    .pipe(gulp.dest('./_build/stylesheets/'))

gulp.task 'build', ['buildCopy', 'buildJs', 'buildSass'], ->
  gulp.src('src/index.hbs')
    .pipe(buildIndex.prod(["scripts/all-#{cacheBuster}.js"], ["stylesheets/all-#{cacheBuster}.css"]))
    .pipe(gulp.dest('./_build/'))

gulp.task 'prod', ['build'], ->
  server '_build', 8081


# Deploy

gulp.task 'deploy', ['build'], ->
  deploy()


# Misc

gulp.task 'cleanBuild', ->
  gulp.src('_build/*', read: false).pipe(clean())

gulp.task 'cleanDev', ->
  gulp.src('_dev/*', read: false).pipe(clean())

gulp.task 'clean', ['cleanBuild', 'cleanDev']
