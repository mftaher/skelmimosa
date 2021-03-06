{exec} = require 'child_process'
path =   require "path"
fs =     require "fs"

logger = require 'logmimosa'
wrench = require "wrench"
rimraf = require "rimraf"

retrieveRegistry = require('../util').retrieveRegistry

windowsDrive = /^[A-Za-z]:\\/
_isSystemPath = (str) ->
  windowsDrive.test(str) or str.indexOf("/") is 0

_isGitHub = (s) ->
  s.indexOf("https://github") is 0 or s.indexOf("git@github") is 0 or s.indexOf("git://github") is 0

_newSkeleton = (skeletonName, directory, opts) ->
  if opts.debug
    logger.setDebug()
    process.env.DEBUG = true

  directory = if directory?
    path.join process.cwd(), directory
  else
    process.cwd()

  if _isGitHub(skeletonName)
    _cloneGitHub(skeletonName, directory)
  else if _isSystemPath(skeletonName)
    _moveDirectoryContents skeletonName, directory
    logger.success "Copied local skeleton to [[ #{directory} ]]"
  else
    retrieveRegistry (registry) ->
      skels = registry.skels.filter (s) -> s.name is skeletonName
      if skels.length is 1
        logger.info "Found skeleton in registry"
        _cloneGitHub skels[0].url, directory
      else
        logger.error "Unable to find a skeleton matching name [[ #{skeletonName} ]]"

_cloneGitHub = (skeletonName, directory) ->
  logger.info "Cloning GitHub repo [[ #{skeletonName} ]] to temp holding directory."

  exec "git clone #{skeletonName} temp-mimosa-skeleton-holding-directory", (error, stdout, stderr) ->
    return logger.error "Error cloning git repo: #{stderr}" if error?

    inPath = path.join process.cwd(),"temp-mimosa-skeleton-holding-directory"
    logger.info "Moving cloned repo to  [[ #{directory} ]]."
    _moveDirectoryContents inPath, directory
    logger.info "Cleaning up..."
    rimraf inPath, (err) ->
      if err
        if process.platform is 'win32'
          logger.warn "A known Windows/Mimosa has made the directory at [[ #{inPath} ]] unremoveable. You will want to clean that up.  Apologies!"
          logger.success "Skeleton successfully cloned from GitHub."
        else
          logger.error "An error occurred cleaning up the temporary holding directory", err
      else
        logger.success "Skeleton successfully cloned from GitHub."

_moveDirectoryContents = (sourcePath, outPath) ->
  contents = wrench.readdirSyncRecursive(sourcePath).filter (p) ->
    p.indexOf('.git') isnt 0 or p.indexOf('.gitignore') is 0

  unless fs.existsSync outPath
    fs.mkdirSync outPath

  for item in contents
    fullSourcePath = path.join sourcePath, item
    fileStats = fs.statSync fullSourcePath
    fullOutPath = path.join(outPath, item)
    if fileStats.isDirectory()
      logger.debug "Copying directory: [[ #{fullOutPath} ]]"
      wrench.mkdirSyncRecursive fullOutPath, 0o0777
    if fileStats.isFile()
      logger.debug "Copying file: [[ #{fullOutPath} ]]"
      fileContents = fs.readFileSync fullSourcePath
      fs.writeFileSync fullOutPath, fileContents

register = (program) ->
  program
    .command('skel:new <skeletonName> [directory]')
    .description("Create a Mimosa project using a skeleton")
    .option("-D, --debug", "run in debug mode")
    .action(_newSkeleton)
    .on '--help', =>
      logger.green('  The skel:new command will create a new project using a Mimosa skeleton of your choice.')
      logger.green('  The first argument passed to skel:new is the name of the skeleton to use.  The name can')
      logger.green('  take several forms.  It can be either the 1) name of the skeleton from the skeleton')
      logger.green('  registry, 2) the github URL of the skeleton or 3) the path to the skeleton if the')
      logger.green('  skeleton is on the file system for when skeleton development is taking place. The second')
      logger.green('  argument is the name of the directory to place the skeleton in. If the directory does')
      logger.green('  not exist, Mimosa will create it. If the directory is not provided, the skeleton will be')
      logger.green('  placed in the current directory.')
      logger.blue( '\n    $ mimosa skel:new <skeletonName> <directory>\n')

module.exports = (program) -> register(program)