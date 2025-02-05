<?php

use Robo\ResultData;
use Robo\Tasks;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;

/**
 * Custom RoboFile commands for this project.
 *
 * @param InputInterface $input
 * @param OutputInterface $output
 *
 * @class RoboFile
 */
class RoboFile extends Tasks
{
    /**
     * Placeholder for your own project's commands.
     *
     * @command drupal-project:custom-command
     *
     * @return void
     *
     * @throws \Exception
     */
    public function customCommand(InputInterface $input, OutputInterface $output): void
    {
        $io = new SymfonyStyle($input, $output);
        $io->comment('This is just a placeholder command, please add your own custom commands here. Please edit : ' . __FILE__);
    }

    /**
     * Generate a static site from Drupal with Tome.
     *
     * @command drupal-project:static
     *
     * @aliases static
     *
     * @param bool $incremental
     *   (Default false) If only content changes have happened, you can set this to 1 to make
     *   this command faster.
     * @param bool $start_server
     *   (Default true) Start an HTTP server with node.
     *
     * @return \Robo\ResultData
     */
    public function static(
        InputInterface $input,
        OutputInterface $output,
        bool $incremental = FALSE,
        bool $start_server = TRUE,
    ): ResultData
    {
        $io = new SymfonyStyle($input, $output);
        if (!$incremental && is_dir("html")) {
            $io->info('Removing pre-existing static site.');
            $this->_cleanDir("html");
        } else {
            $io->info('Doing an incremental update');
        }

        $this->_exec('./drush.sh state:set xmlsitemap_base_url http://127.0.0.1:8080');
        $this->_exec('./drush.sh xmlsitemap:regenerate');
        $this->_exec('./drush.sh tome:static');
        $this->_exec('./drush.sh state:set xmlsitemap_base_url http://digitalgov.lndo.site');
        $this->_exec('./drush.sh xmlsitemap:regenerate');
        if ($start_server) {
            $this->_exec('npm install && npx http-server html');
        }

        return new ResultData();
    }


    /**
     * Export default content.
     *
     * @command drupal-project:export-content
     *
     * @aliases export-content
     *
     * @return \Robo\ResultData
     *
     * @throws \Exception
     */
    public function exportContent(
        InputInterface $input,
        OutputInterface $output,
        array $opts = [
            'path' => 'modules/custom/default_content_config',
            'entities' => [
                'node',
                'menu_link_content',
                'media',
                'redirect',
                'user',
                'config_pages',
                'taxonomy_term',
            ],
        ]
    ): ResultData
    {

        $path =  $opts['path'];
        $entities = $opts['entities'];
        $io = new SymfonyStyle($input, $output);
        if (is_dir("web/$path/content")) {
            $io->info('Removing existing default content exported.');
            $this->_cleanDir("web/$path/content");
        }
        foreach ($entities as $entity) {
            $io->info("Exporting $entity as default content");
            $this->_exec("./drush.sh default-content:export-references $entity --folder=$path/content");
        }
        $io->info("Finished exporting default content to $path/content");

        return new ResultData();
    }

    /**
     * Shared functionality to help create and re-tag a release.
     *
     * @param string $hotfix_or_release
     *    Either 'hotfix' or 'release'.
     * @param string $semantic_version
     *    A semantic version number in the form x.y.z. Release must end in 0.
     *
     * @return array
     *    An indexed array of [$tag_description, $new_branch_name, $source_branch].
     *
     * @throws \Exception
     */

    protected function getVariablesForRelease(string $hotfix_or_release, string $semantic_version): array
    {
        if (!in_array($hotfix_or_release, ['hotfix', 'release'])) {
            throw new InvalidArgumentException("hotfix_or_release must be either 'hotfix' or 'release', '$hotfix_or_release' given.");
        }

        // @see https://regex101.com/r/Ly7O1x/3/.
        if ($hotfix_or_release === 'hotfix') {
            if (!preg_match('/^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>[1-9]\d*)$/', $semantic_version)) {
                throw new InvalidArgumentException("semantic_version must be in the form x.y.z, where z is greater than 0, '$semantic_version' given.");
            }
        } else if (!preg_match('/^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0)$/', $semantic_version)) {
            throw new InvalidArgumentException("semantic_version must be in the form x.y.z, where z is 0, '$semantic_version' given.");
        }
        $this->_exec('git status');
        if (`git status --porcelain`) {
            throw new \Exception('Your "git status" must be clean of any changes or untracked files before continuing. Please see the output of "git status" above.');
        }
        if ($hotfix_or_release === 'hotfix') {
            $source_branch = 'main';
            $tag_description = "Hotfix version $semantic_version";
        } else {
            $source_branch = 'develop';
            $tag_description = "Release version $semantic_version";
        }

        $new_branch_name = "$hotfix_or_release/$semantic_version";

        return [$tag_description, $new_branch_name, $source_branch];
    }

    /**
     * Create a release.
     *
     * @command drupal-project:create-release
     *
     * @aliases create-release
     *
     * @param string $hotfix_or_release
     *   Either 'hotfix' or 'release'.
     * @param string $semantic_version
     *   A semantic version number in the form x.y.z. Release must end in 0.
     *
     * @return \Robo\ResultData
     *
     * @throws \Exception
     */
    public function createRelease(
        InputInterface $input,
        OutputInterface $output,
        string $hotfix_or_release,
        string $semantic_version,
    ): ResultData
    {
        [$tag_description, $new_branch_name, $source_branch] = $this->getVariablesForRelease($hotfix_or_release, $semantic_version);

        `git fetch`;
        // Checkout the branch that the release will be created from.
        $this->taskGitStack()
            ->stopOnFail()
            ->checkout($source_branch)
            ->run();

        // If you trying to test this function, you will need to temp change
        // $source_branch to whatever branch you are working in, otherwise,
        // your changes will get wiped out.
        // You will also want to comment the following line out, since it will
        // also wipe out your changes.
        `git reset --hard origin/$source_branch`;

        // Create the new release branch.
        `git checkout -b $new_branch_name`;

        // Create a new release tag and push the release branch and tag.
        $this->taskGitStack()
            ->stopOnFail()
            ->push('origin', $new_branch_name)
            ->tag("v$semantic_version", $tag_description)
            ->push('origin', "v$semantic_version")
            ->run();

        return new ResultData();
    }

    /**
     * Re-creates the tag for a release after updates have been pushed.
     *
     * The release branch will already be up to date because a feature branch
     * should have been pushed to it, but the initial tag will be out of date
     * now. This checks out the current version of the release, deletes the tag
     * then pushes back up the tag.
     *
     * @command drupal-project:re-tag-release
     *
     * @aliases re-tag
     *
     * @param string $hotfix_or_release
     *   Either 'hotfix' or 'release'.
     * @param string $semantic_version
     *   A semantic version number in the form x.y.z. Release must end in 0.
     *
     * @return \Robo\ResultData
     *
     * @throws \Exception
     */
    public function reTagRelease(
        InputInterface $input,
        OutputInterface $output,
        string $hotfix_or_release,
        string $semantic_version,
    ): ResultData
    {
        [$tag_description, $new_branch_name] = $this->getVariablesForRelease($hotfix_or_release, $semantic_version);

        `git fetch`;
        // Check back out the release branch that has been updated by a feature
        // request and is ahead of the source branch.
        $this->taskGitStack()
            ->stopOnFail()
            ->checkout($new_branch_name)
            ->run();

        // Ensure that the release is at the latest.
        `git reset --hard origin/$new_branch_name`;

        // Delete the old tag locally and remotely.
        `git tag --delete v$semantic_version`;
        `git push origin --delete v$semantic_version`;

        // Create a new tag of the same named based on the updated release
        // branch.
        $this->taskGitStack()
            ->stopOnFail()
            ->tag("v$semantic_version", $tag_description)
            ->push('origin', "v$semantic_version")
            ->run();

        return new ResultData();
    }

}
