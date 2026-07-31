function audit_p23_source_workbook
% AUDIT_P23_SOURCE_WORKBOOK
% Confirms whether participant 23 (Becky) has duplicated values between
% the Spatiotemporal and WalkingSpeeds sheets.
%
% Place this script in the same folder as:
%   Project FYP (Alpha)(1)(1).xlsx
%
% Then run:
%   audit_p23_source_workbook

clear; clc;

%% USER-EDITABLE PATH
scriptDir = fileparts(mfilename('fullpath'));
inputWorkbook = fullfile(scriptDir, 'Project FYP (Alpha)(1)(1).xlsx');

if ~isfile(inputWorkbook)
    error('Workbook not found: %s', inputWorkbook);
end

%% READ SOURCE SHEETS
spatio = readcell(inputWorkbook, ...
    'Sheet', 'Spatiotemporal', ...
    'UseExcel', false);

speeds = readcell(inputWorkbook, ...
    'Sheet', 'WalkingSpeeds', ...
    'UseExcel', false);

participantID = 23;

spatioRow = findNumericID(spatio(:,2), participantID);
speedRow  = findNumericID(speeds(:,2), participantID);

if isempty(spatioRow)
    error('Participant %d not found in Spatiotemporal sheet.', participantID);
end

if isempty(speedRow)
    error('Participant %d not found in WalkingSpeeds sheet.', participantID);
end

participantNameSpatio = string(spatio{spatioRow,1});
participantNameSpeed  = string(speeds{speedRow,1});

%% SOURCE COLUMN DEFINITIONS
% Spatiotemporal sheet:
%   C1 stride length: C:E
%   C2 stride length: G:I
%   C3 stride length: K:M
%
% WalkingSpeeds sheet measured-speed section:
%   C1 measured speed: M:O
%   C2 measured speed: Q:S
%   C3 measured speed: U:W

trialLabels = [ ...
    "C1_T1"; "C1_T2"; "C1_T3"; ...
    "C2_T1"; "C2_T2"; "C2_T3"; ...
    "C3_T1"; "C3_T2"; "C3_T3"];

spatioCols = [3 4 5 7 8 9 11 12 13];
speedCols  = [13 14 15 17 18 19 21 22 23];

strideLengthM   = cellVectorToDouble(spatio(spatioRow, spatioCols));
measuredSpeedKmh = cellVectorToDouble(speeds(speedRow, speedCols));

exactMatch = abs(strideLengthM - measuredSpeedKmh) < 1e-12;

spatioCell = strings(numel(spatioCols),1);
speedCell  = strings(numel(speedCols),1);

for i = 1:numel(spatioCols)
    spatioCell(i) = columnNumberToName(spatioCols(i)) + string(spatioRow);
    speedCell(i)  = columnNumberToName(speedCols(i)) + string(speedRow);
end

Audit = table( ...
    repmat(participantID,numel(trialLabels),1), ...
    repmat(participantNameSpatio,numel(trialLabels),1), ...
    trialLabels, ...
    spatioCell, ...
    strideLengthM, ...
    speedCell, ...
    measuredSpeedKmh, ...
    exactMatch, ...
    'VariableNames', { ...
        'ParticipantID', ...
        'ParticipantName', ...
        'Trial', ...
        'SpatiotemporalCell', ...
        'StrideLength_m', ...
        'WalkingSpeedCell', ...
        'MeasuredSpeed_kmh', ...
        'ExactNumericalMatch'});

fprintf('\n============================================================\n');
fprintf('P23 SOURCE-WORKBOOK AUDIT\n');
fprintf('============================================================\n');
fprintf('Spatiotemporal participant: %s, row %d\n', ...
    participantNameSpatio, spatioRow);
fprintf('WalkingSpeeds participant:  %s, row %d\n\n', ...
    participantNameSpeed, speedRow);

disp(Audit);

fprintf('\nInterpretation:\n');

if all(exactMatch(4:9))
    fprintf(['CONFIRMED: all six C2/C3 P23 stride-length values exactly match ' ...
        'the measured walking-speed values in km/h.\n']);
    fprintf(['The duplicated values are already present in the source workbook; ' ...
        'they were not created by the clean-data extraction code.\n']);
else
    fprintf('The six C2/C3 values are not all exact matches. Inspect the table above.\n');
end

if any(exactMatch(1:3))
    fprintf('C1 also contains one or more exact matches and requires review.\n');
else
    fprintf('C1 stride lengths do not match the measured C1 speed values.\n');
end

%% SAVE AUDIT TABLE
outputFile = fullfile(scriptDir, 'P23_Source_Workbook_Audit.xlsx');

if isfile(outputFile)
    delete(outputFile);
end

writetable(Audit, outputFile, 'Sheet', 'P23 Audit');

notes = {
    'Conclusion';
    'P23 is participant Becky.';
    'Spatiotemporal row 25 contains C2 stride values G25:I25 = 3.05, 2.96, 3.08 m.';
    'WalkingSpeeds row 24 contains measured C2 speeds Q24:S24 = 3.05, 2.96, 3.08 km/h.';
    'Spatiotemporal row 25 contains C3 stride values K25:M25 = 4.59, 4.55, 4.46 m.';
    'WalkingSpeeds row 24 contains measured C3 speeds U24:W24 = 4.59, 4.55, 4.46 km/h.';
    'These source values should be checked against the original acquisition/export record before correction.'
    };

writecell(notes, outputFile, 'Sheet', 'Conclusion', 'Range', 'A1');

fprintf('\nAudit saved to:\n  %s\n', outputFile);

end

%% LOCAL FUNCTIONS
function row = findNumericID(columnCells, participantID)
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
