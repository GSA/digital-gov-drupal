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
     * Export default content.
     *
     * @command drupal-project:export-content
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
                'taxonomy',
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


}
