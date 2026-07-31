function audit_p23_source_workbook_LITERATURE_ALIGNED
% =========================================================================
% P23 SOURCE-WORKBOOK CONSISTENCY AUDIT
% =========================================================================
%
% Purpose
% -------
% Confirm directly from the source workbook whether P23's three-trial
% stride-length vectors are duplicated in the measured-speed section.
%
% This audit uses no physiological cut-off and makes no automatic inference
% from an isolated large or small gait value. It compares source cells with
% source cells and reports the exact locations and units.
%
% The underlying principles are transparency, technical validation and
% explicit reporting of data-processing decisions:
%
% [1] Scientific Data. Submission Guidelines: Technical Validation.
%     https://www.nature.com/sdata/publish/submission-guidelines
%
% [2] Lee KJ, et al. Framework for the treatment and reporting of missing
%     data in observational studies: the TARMOS framework.
%     J Clin Epidemiol. 2021;134:79-88.
%     https://doi.org/10.1016/j.jclinepi.2021.01.008
%
% Important
% ---------
% An exact cross-variable duplication is a source-consistency finding.
% Literature cannot supply replacement values. Any correction must be made
% from the original acquisition/export record.
%
% Run
% ---
%   audit_p23_source_workbook_LITERATURE_ALIGNED
%
% =========================================================================

clear;
clc;

scriptDir = fileparts(mfilename('fullpath'));

inputWorkbook = fullfile( ...
    scriptDir, ...
    'Project FYP (Alpha)(1)(1).xlsx');

if ~isfile(inputWorkbook)
    error('Workbook not found: %s',inputWorkbook);
end

spatio = readcell(inputWorkbook, ...
    'Sheet','Spatiotemporal', ...
    'UseExcel',false);

speeds = readcell(inputWorkbook, ...
    'Sheet','WalkingSpeeds', ...
    'UseExcel',false);

participantID = 23;

spatioRow = findNumericID(spatio(:,2),participantID);
speedRow = findNumericID(speeds(:,2),participantID);

if isempty(spatioRow)
    error('P23 was not found in the Spatiotemporal sheet.');
end

if isempty(speedRow)
    error('P23 was not found in the WalkingSpeeds sheet.');
end

participantNameSpatio = string(spatio{spatioRow,1});
participantNameSpeed = string(speeds{speedRow,1});

trialLabels = [ ...
    "C1_T1";"C1_T2";"C1_T3"; ...
    "C2_T1";"C2_T2";"C2_T3"; ...
    "C3_T1";"C3_T2";"C3_T3"];

spatioColumns = [3 4 5 7 8 9 11 12 13];
measuredSpeedColumns = [13 14 15 17 18 19 21 22 23];

strideLengthM = cellVectorToDouble( ...
    spatio(spatioRow,spatioColumns));

measuredSpeedKmh = cellVectorToDouble( ...
    speeds(speedRow,measuredSpeedColumns));

individualCellMatch = ...
    isfinite(strideLengthM) & ...
    isfinite(measuredSpeedKmh) & ...
    abs(strideLengthM - measuredSpeedKmh) < 1e-12;

conditionVectorDuplicate = false(9,1);

for c = 1:3

    idx = (c-1)*3 + (1:3);

    conditionVectorDuplicate(idx) = ...
        all(individualCellMatch(idx));
end

spatioCell = strings(9,1);
speedCell = strings(9,1);

for i = 1:9
    spatioCell(i) = ...
        columnNumberToName(spatioColumns(i)) + string(spatioRow);

    speedCell(i) = ...
        columnNumberToName(measuredSpeedColumns(i)) + string(speedRow);
end

Audit = table( ...
    repmat(participantID,9,1), ...
    repmat(participantNameSpatio,9,1), ...
    trialLabels, ...
    spatioCell, ...
    strideLengthM, ...
    speedCell, ...
    measuredSpeedKmh, ...
    individualCellMatch, ...
    conditionVectorDuplicate, ...
    'VariableNames',{ ...
        'ParticipantID', ...
        'ParticipantName', ...
        'Trial', ...
        'StrideSourceCell', ...
        'StrideLength_m', ...
        'MeasuredSpeedSourceCell', ...
        'MeasuredSpeed_kmh', ...
        'IndividualCellExactMatch', ...
        'CompleteConditionVectorDuplicate'});

fprintf('\n============================================================\n');
fprintf('P23 SOURCE CONSISTENCY AUDIT\n');
fprintf('============================================================\n');
fprintf('Spatiotemporal identity: %s, row %d\n', ...
    participantNameSpatio,spatioRow);
fprintf('WalkingSpeeds identity:  %s, row %d\n\n', ...
    participantNameSpeed,speedRow);

disp(Audit);

if all(conditionVectorDuplicate(4:6))
    fprintf('CONFIRMED: P23 C2 contains a complete three-trial vector duplication.\n');
end

if all(conditionVectorDuplicate(7:9))
    fprintf('CONFIRMED: P23 C3 contains a complete three-trial vector duplication.\n');
end

if ~any(conditionVectorDuplicate(1:3))
    fprintf('P23 C1 does not contain a complete three-trial vector duplication.\n');
end

fprintf(['\nInterpretation: the source workbook contains identical numeric ' ...
    'vectors under variables with different units. The raw records should ' ...
    'be preserved, and stride-derived summaries for the affected ' ...
    'participant-condition rows should be excluded pending correction ' ...
    'from the original acquisition/export record.\n']);

outputFile = fullfile( ...
    scriptDir, ...
    'P23_Source_Workbook_Audit_LITERATURE_ALIGNED.xlsx');

if isfile(outputFile)
    delete(outputFile);
end

writetable(Audit,outputFile,'Sheet','P23 Audit');

References = table( ...
    [1;2], ...
    [ ...
        "Scientific Data. Submission Guidelines."
        "Lee KJ, et al. TARMOS missing-data framework. J Clin Epidemiol. 2021;134:79-88."], ...
    [ ...
        "https://www.nature.com/sdata/publish/submission-guidelines"
        "https://doi.org/10.1016/j.jclinepi.2021.01.008"], ...
    'VariableNames',{'ReferenceNumber','Citation','URL'});

writetable(References,outputFile,'Sheet','References');

fprintf('\nAudit workbook saved to:\n  %s\n',outputFile);

end

%% LOCAL FUNCTIONS

function row = findNumericID(columnCells,participantID)

row = [];

for r = 1:numel(columnCells)

    value = columnCells{r};

    if isnumeric(value) && isscalar(value) && ...
            isfinite(value) && value == participantID

        row = r;
        return;
    end
end
end

function values = cellVectorToDouble(cells)

values = nan(numel(cells),1);

for i = 1:numel(cells)

    value = cells{i};

    if isnumeric(value) && isscalar(value)
        values(i) = double(value);
    end
end
end

function name = columnNumberToName(columnNumber)

name = "";
n = columnNumber;

while n > 0
    remainder = mod(n-1,26);
    name = string(char(65 + remainder)) + name;
    n = floor((n-1)/26);
end
end
