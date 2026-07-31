function saveCurrentFigure(fig,outDir,baseName)
%SAVECURRENTFIGURE Save current MATLAB figure in reusable formats.
%
% Usage:
%   saveCurrentFigure(gcf, fullfile(pwd,'Results','Figures'), 'Hip_predictors')
%
% Saves:
%   .fig  MATLAB editable figure
%   .png  high-resolution image
%   .tif  high-resolution image for documents
%   .pdf  vector-ish export when available

if nargin < 1 || isempty(fig)
    fig = gcf;
end
if nargin < 2 || isempty(outDir)
    outDir = fullfile(pwd,'Results','Figures');
end
if nargin < 3 || isempty(baseName)
    baseName = ['Figure_' datestr(now,'yyyymmdd_HHMMSS')];
end

if ~exist(outDir,'dir')
    mkdir(outDir);
end

% Make filenames safe
baseName = regexprep(baseName,'[^\w\-]','_');

figPath = fullfile(outDir,[baseName '.fig']);
pngPath = fullfile(outDir,[baseName '.png']);
tifPath = fullfile(outDir,[baseName '.tif']);
pdfPath = fullfile(outDir,[baseName '.pdf']);

savefig(fig, figPath);

try
    exportgraphics(fig, pngPath, 'Resolution', 300);
    exportgraphics(fig, tifPath, 'Resolution', 300);
    exportgraphics(fig, pdfPath, 'ContentType', 'vector');
catch
    print(fig, pngPath, '-dpng', '-r300');
    print(fig, tifPath, '-dtiff', '-r300');
    print(fig, pdfPath, '-dpdf', '-bestfit');
end

fprintf('Saved figure:\n  %s\n  %s\n  %s\n  %s\n', figPath, pngPath, tifPath, pdfPath);
end
