// Import Gulp 5
const { parallel, series, watch } = require("gulp");

const scripts = require("./gulp-includes/gulp/scripts");
const styles = require("./gulp-includes/gulp/styles");

function gulpWatch() {
  const THEME_DIR = "./";
  watch(`${THEME_DIR}/css/uswds/**/*.scss`, styles.buildSass);
  watch(`${THEME_DIR}/css/new/**/*.scss`, styles.buildSass);
  watch(`${THEME_DIR}/js/*.js`, scripts.compile);
}

// Define public tasks
exports.copyUswdsJS = scripts.copyUswdsJS;
exports.copyUswdsImages = styles.copyUswdsImages;
exports.copyUswdsFonts = styles.copyUswdsFonts;
exports.buildSprite = styles.buildSprite;
exports.copyUswdsAssets = parallel(
  styles.copyUswdsImages,
  styles.copyUswdsFonts
);
exports.buildAssets = parallel(styles.buildSass, scripts.compile);
exports.buildSass = styles.buildSass;
exports.buildJS = scripts.compile;
exports.watch = gulpWatch;
//exports.default = series(styles.buildSass, gulpWatch);
exports.default = series(exports.copyUswdsAssets, exports.buildAssets)
