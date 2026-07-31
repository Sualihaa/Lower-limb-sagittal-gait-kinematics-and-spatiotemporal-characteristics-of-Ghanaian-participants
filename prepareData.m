% =========================================================================
% FIT NORMAL GAIT: Predict kinematics based on walking speed, age, sex, BMI
% =========================================================================
% Function: prepareData
% =========================================================================
% Original author: F. Moissenet
% Original creation: 06 July 2017
%
% Corrected version:
%   1. Sorts every variable using the same walking-speed order.
%   2. Applies the Froude-speed limits to the sorted speed vector.
%   3. Checks that every observation-level field has the same length.
%   4. Rejects non-finite walking-speed observations.
% =========================================================================

function Sort = prepareData(Raw, minVf, maxVf)

% =========================================================================
% Input checks
% =========================================================================
if nargin ~= 3
    error('prepareData requires three inputs: Raw, minVf and maxVf.');
end

if ~isscalar(minVf) || ~isfinite(minVf)
    error('minVf must be a finite scalar.');
end

if ~isscalar(maxVf) || ~isfinite(maxVf)
    error('maxVf must be a finite scalar.');
end

if minVf >= maxVf
    error('minVf must be smaller than maxVf.');
end

requiredFields = { ...
    'kinematics', ...
    'walkingSpeed', ...
    'stepLength', ...
    'cadence', ...
    'IFS1', ...
    'IFS2', ...
    'IFO', ...
    'CFS', ...
    'CFO', ...
    'age', ...
    'sex', ...
    'BMI', ...
    'LL'};

for f = 1:numel(requiredFields)
    if ~isfield(Raw, requiredFields{f})
        error('Raw is missing the required field: Raw.%s', ...
            requiredFields{f});
    end
end

% Convert observation-level variables to row vectors.
Raw.walkingSpeed = reshape(Raw.walkingSpeed, 1, []);
Raw.stepLength   = reshape(Raw.stepLength,   1, []);
Raw.cadence      = reshape(Raw.cadence,      1, []);
Raw.IFS1         = reshape(Raw.IFS1,         1, []);
Raw.IFS2         = reshape(Raw.IFS2,         1, []);
Raw.IFO          = reshape(Raw.IFO,          1, []);
Raw.CFS          = reshape(Raw.CFS,          1, []);
Raw.CFO          = reshape(Raw.CFO,          1, []);
Raw.age          = reshape(Raw.age,          1, []);
Raw.sex          = reshape(Raw.sex,          1, []);
Raw.BMI          = reshape(Raw.BMI,          1, []);
Raw.LL           = reshape(Raw.LL,           1, []);

nObservations = numel(Raw.walkingSpeed);

if size(Raw.kinematics, 2) ~= nObservations
    error(['Raw.kinematics contains %d columns, but Raw.walkingSpeed ', ...
        'contains %d observations.'], ...
        size(Raw.kinematics, 2), nObservations);
end

fieldsToCheck = requiredFields(3:end);

for f = 1:numel(fieldsToCheck)
    fieldName = fieldsToCheck{f};

    if numel(Raw.(fieldName)) ~= nObservations
        error(['Raw.%s contains %d observations, whereas ', ...
            'Raw.walkingSpeed contains %d.'], ...
            fieldName, numel(Raw.(fieldName)), nObservations);
    end
end

% =========================================================================
% Sort all data by ascending dimensionless walking speed
% =========================================================================
[swalkingSpeed, sortIndex] = sort(Raw.walkingSpeed);

skinematics = Raw.kinematics(:, sortIndex);
sstepLength = Raw.stepLength(sortIndex);
scadence    = Raw.cadence(sortIndex);
sIFS1       = Raw.IFS1(sortIndex);
sIFS2       = Raw.IFS2(sortIndex);
sIFO        = Raw.IFO(sortIndex);
sCFS        = Raw.CFS(sortIndex);
sCFO        = Raw.CFO(sortIndex);
sage        = Raw.age(sortIndex);
ssex        = Raw.sex(sortIndex);
sBMI        = Raw.BMI(sortIndex);
sLL         = Raw.LL(sortIndex);

% =========================================================================
% Retain observations inside the specified Froude-speed range
%
% The upper limit remains exclusive to reproduce the original rule:
%     minVf <= walking speed < maxVf
% =========================================================================
keep = isfinite(swalkingSpeed) & ...
       swalkingSpeed >= minVf & ...
       swalkingSpeed < maxVf;

% =========================================================================
% Construct output
% =========================================================================
Sort = struct();

Sort.kinematics   = skinematics(:, keep);
Sort.walkingSpeed = swalkingSpeed(keep);
Sort.stepLength   = sstepLength(keep);
Sort.cadence      = scadence(keep);
Sort.IFS1         = sIFS1(keep);
Sort.IFS2         = sIFS2(keep);
Sort.IFO          = sIFO(keep);
Sort.CFS          = sCFS(keep);
Sort.CFO          = sCFO(keep);
Sort.age          = sage(keep);
Sort.sex          = ssex(keep);
Sort.BMI          = sBMI(keep);
Sort.LL           = sLL(keep);

if isempty(Sort.walkingSpeed)
    warning(['prepareData:noObservationsRetained: ', ...
        'No observations were retained between minVf = %.6f ', ...
        'and maxVf = %.6f.'], minVf, maxVf);
end

end
%% ORIGINAL
% % =========================================================================
% % =========================================================================
% % FIT NORMAL GAIT: Predict kinematics based on walking speed, age, sex, BMI
% % =========================================================================
% % Function: prepareData
% % =========================================================================
% % Authors: F. Moissenet
% % Creation: 06 July 2017
% % Version: v1.0
% % =========================================================================
% % =========================================================================
% 
% function Sort = prepareData(Raw,minVf,maxVf)
% 
% % =========================================================================
% % Initialisation
% % =========================================================================
% Sort.kinematics = [];
% Sort.walkingSpeed = [];
% Sort.stepLength = [];
% Sort.cadence = [];
% Sort.IFS1 = [];
% Sort.IFS2 = [];
% Sort.IFO = [];
% Sort.CFS = [];
% Sort.CFO = [];
% Sort.age = [];
% Sort.sex = [];
% Sort.BMI = [];
% Sort.LL = [];
% 
% % =========================================================================
% % Prepare data for treatment
% % =========================================================================
% 
% % Sort raw data by ascending walking speed
% % -------------------------------------------------------------------------
% [S,I] = sort(Raw.walkingSpeed);
% skinematics = Raw.kinematics(:,I);
% sstepLength = Raw.stepLength(:,I);
% scadence = Raw.cadence(:,I);
% swalkingSpeed = S;
% sIFS1 = Raw.IFS1(:,I);
% sIFS2 = Raw.IFS2(:,I);
% sIFO = Raw.IFO(:,I);
% sCFS = Raw.CFS(:,I);
% sCFO = Raw.CFO(:,I);
% sage = Raw.age(:,I);
% ssex = Raw.sex(:,I);
% sBMI = Raw.BMI(:,I);
% sLL = Raw.LL(:,I);
% 
% % Remove extreme walking speed values
% % -------------------------------------------------------------------------
% index = find(Raw.walkingSpeed >= minVf & Raw.walkingSpeed < maxVf);
% Sort.kinematics = skinematics(:,index);
% Sort.walkingSpeed = swalkingSpeed(:,index);
% Sort.stepLength = sstepLength(:,index);
% Sort.cadence = scadence(:,index);
% Sort.IFS1 = sIFS1(:,index);
% Sort.IFS2 = sIFS2(:,index);
% Sort.IFO = sIFO(:,index);
% Sort.CFS = sCFS(:,index);
% Sort.CFO = sCFO(:,index);
% Sort.age = sage(:,index);
% Sort.sex = ssex(:,index);
% Sort.BMI = sBMI(:,index);
% Sort.LL = sLL(:,index);