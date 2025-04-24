### Runbook for `build-theme.sh`

#### Introduction

The script `build-theme.sh` is used for compiling and building a custom theme for the project. The script manages the process by installing necessary dependencies and running the build command using `npm` and `gulp`.

#### Technical Breakdown

1. The script is to globally install `gulp` via npm:

```bash
npm install -g gulp
```

2. The script changes the directory to where the custom theme is located:

```bash
cd web/themes/custom/digitalgov
```

3. It installs npm dependencies specific to this theme directory:

```bash
npm install
```

4. The script runs a build command using npm:

```bash
npm run build
```

This process is designed to compile theme assets such as CSS, JavaScript, and other resources necessary to render a consistent style in a web application.

**Troubleshooting**

- **Error: npm command not found**
  - This usually indicates that Node.js and npm are not installed on the machine. Ensure Node.js and npm are installed by following the official installation guide at https://nodejs.org/en/download/.

- **Error: gulp command not found**
  - If the global installation of gulp fails, the script may not proceed correctly. Verify that `gulp` is installed globally by checking its version with `gulp -v`. If it fails, reinstall `gulp` using `npm install -g gulp`.

- **npm install fails**
  - If dependencies fail to install, ensure you have network connectivity and try running `npm cache clean --force` to clear any corrupted cache.

- **Build process hangs or fails**
  - Check the specific errors provided in the console. Errors might be related to missing dependencies or outdated versions. Review the `package.json` and `gulpfile.js` in the theme directory to adjust any misconfigurations.

- **Theme assets not updating in the web app**
  - Ensure that build artifacts are placed in the correct directories, and that your web server or tooling is correctly configured to pick up the compiled assets. You may need to clear your browser cache or restart your web server.
