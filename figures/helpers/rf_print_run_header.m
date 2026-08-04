function rf_print_run_header(cfg)
fprintf('\n============================================================\n');
fprintf('MULTIPLE-REGRESSION MANUSCRIPT FIGURE PACKAGE\n');
fprintf('Project root : %s\n',cfg.rootDir);
fprintf('Data folder  : %s\n',cfg.dataDir);
fprintf('Model outputs: %s\n',cfg.resultsDir);
fprintf('Figure output: %s\n',cfg.outputDir);
fprintf('============================================================\n');
end
