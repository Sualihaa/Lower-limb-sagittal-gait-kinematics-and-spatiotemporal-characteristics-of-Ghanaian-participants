function format_existing_model_figures(cfg)
%FORMAT_EXISTING_MODEL_FIGURES Re-export existing .fig outputs consistently.
% Scientific geometry is preserved; only typography, line hierarchy, size,
% and output formats are changed.

if nargin < 1
    cfg = rf_resolve_paths(fileparts(fileparts(mfilename('fullpath'))));
end

patterns = {
    '*_predictor_contribution.fig',190,105
    '*_validation_summary.fig',140,95
    '*raw_fit_regression*.fig',190,72
    };

outDir = fullfile(cfg.outputDir,'Existing_Model_Figures_Reformatted');
if ~isfolder(outDir); mkdir(outDir); end

nExported = 0;
for p = 1:size(patterns,1)
    files = dir(fullfile(cfg.sourceFigDir,patterns{p,1}));
    for i = 1:numel(files)
        src = fullfile(files(i).folder,files(i).name);
        fig = openfig(src,'invisible');
        set(fig,'Color','w','Renderer','painters');
        axesList = findall(fig,'Type','axes');
        for a = 1:numel(axesList)
            if isa(axesList(a),'matlab.graphics.illustration.ColorBar')
                continue;
            end
            try
                rf_style_axes(axesList(a),cfg);
            catch
            end
        end
        [~,name] = fileparts(files(i).name);
        outBase = fullfile(outDir,name);
        rf_export_figure(fig,outBase,patterns{p,2},patterns{p,3});
        close(fig);
        nExported = nExported + 1;
    end
end

fprintf('Re-exported %d existing model figure(s).\n',nExported);
if nExported == 0
    warning(['No existing .fig model outputs were found in %s. ' ...
        'This does not affect Figures 1, 2, S1, S2 or S3.'],cfg.sourceFigDir);
end
end
