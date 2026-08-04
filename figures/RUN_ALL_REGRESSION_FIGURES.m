function RUN_ALL_REGRESSION_FIGURES(rootDir)
%RUN_ALL_REGRESSION_FIGURES Generate the complete multiple-regression figure set.
%
% Place this package in the PatternGenerator project root, or pass the root:
%   RUN_ALL_REGRESSION_FIGURES
%   RUN_ALL_REGRESSION_FIGURES('C:\path\to\fmoissenet-PatternGenerator-2315600')
%
% Required before running:
%   1. Data_OURS/Norm_V1.mat, Norm_V2.mat, Norm_V3.mat
%   2. MAIN_fitGait_TRACEABLE has been run, so joint-specific MAT/CSV files exist.
%
% Core manuscript figures:
%   Figure_1_condition_kinematics
%   Figure_2_LOPO_validation
%
% Supplementary/QC figures:
%   Figure_S1_raw_fit_regression_diagnostic
%   Figure_S2_model_performance_summary
%   Figure_S3_knee_polarity_sensitivity
%   Reformatted predictor-contribution and joint-validation figures

if nargin < 1 || strlength(string(rootDir)) == 0
    packageDir = fileparts(mfilename('fullpath'));
    candidate = fileparts(packageDir);
    if isfolder(fullfile(candidate,'Data_OURS')) || ...
            isfolder(fullfile(candidate,'Results_AHENEMA_TRACEABLE')) || ...
            isfolder(fullfile(candidate,'Results_MULTIPLE_REGRESSION_TRACEABLE'))
        rootDir = candidate;
    else
        rootDir = packageDir;
    end
end

rootDir = char(rootDir);
packageDir = fileparts(mfilename('fullpath'));
addpath(packageDir);
addpath(fullfile(packageDir,'helpers'));

cfg = rf_resolve_paths(rootDir);
rf_print_run_header(cfg);

jobs = {
    'Figure 1: condition kinematics', @() make_figure1_condition_kinematics(cfg)
    'Figure 2: LOPO validation', @() make_figure2_LOPO_validation(cfg)
    'Figure S1: raw-fit-regression diagnostic', @() make_figureS1_raw_fit_regression(cfg)
    'Figure S2: model-performance summary', @() make_figureS2_model_performance(cfg)
    'Figure S3: knee-polarity sensitivity', @() make_figureS3_knee_polarity_sensitivity(cfg)
    'Existing model figures: publication re-export', @() format_existing_model_figures(cfg)
    };

status = strings(size(jobs,1),1);
message = strings(size(jobs,1),1);

for i = 1:size(jobs,1)
    fprintf('\n[%d/%d] %s\n',i,size(jobs,1),jobs{i,1});
    try
        jobs{i,2}();
        status(i) = "OK";
        message(i) = "";
    catch ME
        status(i) = "ERROR";
        message(i) = string(ME.message);
        warning('%s failed: %s',jobs{i,1},ME.message);
    end
end

T = table(string(jobs(:,1)),status,message, ...
    'VariableNames',{'Figure','Status','Message'});
writetable(T,fullfile(cfg.outputDir,'Figure_Run_Status.csv'));

disp(T);
fprintf('\nFigure package complete. Outputs:\n  %s\n',cfg.outputDir);
fprintf('Open Figure_Run_Status.csv before using the figures.\n');
end
