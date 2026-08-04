function cfg = rf_resolve_paths(rootDir)
%RF_RESOLVE_PATHS Resolve data, model-output and publication-figure folders.

rootDir = char(rootDir);
if ~isfolder(rootDir)
    error('Project root does not exist: %s',rootDir);
end

cfg = struct();
cfg.rootDir = rootDir;

% Data folder: prefer the project-local Data_OURS.
dataCandidates = {
    fullfile(rootDir,'Data_OURS')
    fullfile(rootDir,'multipleregression_datadescriptor','Data_OURS')
    fullfile(fileparts(rootDir),'multipleregression_datadescriptor','Data_OURS')
    };
cfg.dataDir = firstFolder(dataCandidates);
if isempty(cfg.dataDir)
    error(['Could not find Data_OURS. Put Norm_V1.mat, Norm_V2.mat and ' ...
        'Norm_V3.mat in <project root>\Data_OURS.']);
end

% The original traceable script unfortunately used an Ahenema-labelled folder.
% Prefer the corrected name, but support the legacy folder without changing data.
resultsCandidates = {
    fullfile(rootDir,'Results_MULTIPLE_REGRESSION_TRACEABLE')
    fullfile(rootDir,'Results_AHENEMA_TRACEABLE')
    };
cfg.resultsDir = firstFolder(resultsCandidates);
if isempty(cfg.resultsDir)
    cfg.resultsDir = resultsCandidates{1};
    mkdir(cfg.resultsDir);
end

if contains(cfg.resultsDir,'AHENEMA','IgnoreCase',true)
    warning(['Using legacy folder name Results_AHENEMA_TRACEABLE. The contents ' ...
        'belong to the Ghanaian multiple-regression dataset, not the Ahenema study.']);
end

cfg.matDir = fullfile(cfg.resultsDir,'MAT');
cfg.csvDir = fullfile(cfg.resultsDir,'CSV');
cfg.sourceFigDir = fullfile(cfg.resultsDir,'Figures');
cfg.outputDir = fullfile(rootDir,'Manuscript_Figures_Multiple_Regression');

if ~isfolder(cfg.outputDir); mkdir(cfg.outputDir); end
if ~isfolder(cfg.sourceFigDir); mkdir(cfg.sourceFigDir); end

cfg.conditions = ["C2","C1","C3"];
cfg.conditionLabels = ["Slow","Normal","Fast"];
cfg.normFiles = {
    fullfile(cfg.dataDir,'Norm_V2.mat')
    fullfile(cfg.dataDir,'Norm_V1.mat')
    fullfile(cfg.dataDir,'Norm_V3.mat')
    };

for i = 1:numel(cfg.normFiles)
    if ~isfile(cfg.normFiles{i})
        error('Required condition file missing: %s',cfg.normFiles{i});
    end
end

cfg.joints = ["Hip","Knee","Ankle"];
cfg.jointCodes = ["FE4","FE3","FE2"];
cfg.jointYLabels = ["Hip angle (°)","Knee angle (°)","Ankle angle (°)"];
cfg.fontName = 'Arial';
cfg.fontSize = 8;
cfg.axisLineWidth = 0.75;
cfg.meanLineWidth = 1.5;
cfg.bandAlpha = 0.16;

% Colour-blind-aware palette; line styles also identify conditions.
cfg.conditionColours = [0.000 0.447 0.741; 0.20 0.20 0.20; 0.850 0.325 0.098];
cfg.conditionLineStyles = {'--','-','-.'};
cfg.jointColours = [0.000 0.447 0.741; 0.850 0.325 0.098; 0.466 0.674 0.188];
end

function p = firstFolder(candidates)
p = '';
for k = 1:numel(candidates)
    if isfolder(candidates{k})
        p = candidates{k};
        return;
    end
end
end
