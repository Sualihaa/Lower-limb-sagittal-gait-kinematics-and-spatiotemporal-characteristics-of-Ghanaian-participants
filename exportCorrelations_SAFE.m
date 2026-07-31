function exportCorrelations_SAFE(Joint, Predictors, J, filename)
%EXPORTCORRELATIONS_SAFE Dynamic CSV export for Fmoissenet Predictor structures.
%
% Why this exists:
% The original exportCorrelations.m is hard-coded for a different number of
% predictors and tries to access Predictors(:,:,6). Our current model uses:
%   Constant + Walking speed + Age + Sex + BMI
% so the third dimension is usually 5, not 6.
%
% Usage:
%   filename = 'tableCorrelations_SAFE.csv';
%   exportCorrelations_SAFE(Joint, Predictors, J, filename);

if nargin < 4 || isempty(filename)
    filename = 'tableCorrelations_SAFE.csv';
end

if nargin < 3 || isempty(J)
    J = 1;
end

outDir = fullfile(pwd,'Results');
if ~exist(outDir,'dir')
    mkdir(outDir);
end

outPath = fullfile(outDir, filename);

[nKeypoints, nValues, nPredictors] = size(Predictors);

defaultNames = {'Constant','Walking speed','Age','Sex','BMI'};
predictorNames = cell(1,nPredictors);
for p = 1:nPredictors
    if p <= numel(defaultNames)
        predictorNames{p} = defaultNames{p};
    else
        predictorNames{p} = sprintf('Predictor_%d',p);
    end
end

if isstruct(Joint) && numel(Joint) >= J && isfield(Joint,'name')
    jointName = Joint(J).name;
else
    jointName = sprintf('Joint_%d',J);
end

rows = {};
r = 1;

for kp = 1:nKeypoints
    for valIdx = 1:nValues
        for p = 1:nPredictors

            value = getFieldOrNaN(Predictors(kp,valIdx,p),'value');
            significance = getFieldOrNaN(Predictors(kp,valIdx,p),'significance');

            rows(r,:) = { ...
                jointName, ...
                kp, ...
                valIdx, ...
                predictorNames{p}, ...
                value, ...
                significance ...
                }; %#ok<AGROW>
            r = r + 1;
        end
    end
end

T = cell2table(rows, 'VariableNames', ...
    {'Joint','Keypoint','ParameterIndex','Predictor','Value','Significance'});

writetable(T,outPath);

fprintf('Saved safe correlation export:\n  %s\n', outPath);

end

function x = getFieldOrNaN(S, fieldName)
if isstruct(S) && isfield(S,fieldName)
    x = S.(fieldName);
    if isempty(x)
        x = NaN;
    end
else
    x = NaN;
end

if isnumeric(x) && numel(x) > 1
    x = x(1);
elseif islogical(x)
    x = double(x);
elseif ischar(x) || isstring(x)
    % keep as is
else
    if ~isnumeric(x)
        x = NaN;
    end
end
end
