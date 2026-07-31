function run_gait_descriptive_statistics
% RUN_GAIT_DESCRIPTIVE_STATISTICS
%
% Reproduces the descriptive statistics and QC analysis for:
%   - participant flow and completeness;
%   - demographics of the 24-participant modelling cohort;
%   - trial-level spatiotemporal data;
%   - participant-condition means after averaging three repeated trials;
%   - condition-level descriptive statistics;
%   - P23 source-data anomaly checks;
%   - waveform completeness.
%
% The script does NOT run hypothesis tests.
%
% REQUIRED FILES IN THE SAME INPUT FOLDER
%   Project FYP (Alpha)(1)(1).xlsx
%   Norm_V1.mat
%   Norm_V2.mat
%   Norm_V3.mat
%   dataNorm_C1_clean.mat
%   dataNorm_C2_clean.mat
%   dataNorm_C3_clean.mat
%
% OUTPUT
%   Reproduced_Gait_Descriptive_Statistics.xlsx
%   CSV files in Statistics_Reproduced/
%
% Run:
%   run_gait_descriptive_statistics

clear; clc;

%% ========================================================================
% 1. USER SETTINGS
% =========================================================================
scriptDir = fileparts(mfilename('fullpath'));

% Put the seven required input files in this folder, or edit inputDir.
inputDir = scriptDir;

sourceWorkbook = fullfile(inputDir, 'Project FYP (Alpha)(1).xlsx');

normFiles = {
    fullfile(inputDir, 'Norm_V1.mat')
    fullfile(inputDir, 'Norm_V2.mat')
    fullfile(inputDir, 'Norm_V3.mat')
    };

cleanFiles = {
    fullfile(inputDir, 'dataNorm_C1_clean.mat')
    fullfile(inputDir, 'dataNorm_C2_clean.mat')
    fullfile(inputDir, 'dataNorm_C3_clean.mat')
    };

conditionCodes  = ["C1"; "C2"; "C3"];
conditionLabels = ["Normal"; "Slow"; "Fast"];

% The manuscript history reports 30 recruited participants.
% This cannot be reconstructed from the six MAT files, so it is an explicit
% user-supplied flow value rather than a computed result.
nRecruitedReported = 30;

outputDir = fullfile(scriptDir, 'Statistics_Reproduced');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

outputWorkbook = fullfile(outputDir, ...
    'Reproduced_Gait_Descriptive_Statistics.xlsx');

if isfile(outputWorkbook)
    delete(outputWorkbook);
end

requiredFiles = [{sourceWorkbook}; normFiles; cleanFiles];
for i = 1:numel(requiredFiles)
    if ~isfile(requiredFiles{i})
        error('Required file not found: %s', requiredFiles{i});
    end
end

%% ========================================================================
% 2. LOAD AND VERIFY NORM FILES
% =========================================================================
V = cell(3,1);
for c = 1:3
    V{c} = load(normFiles{c});
end

subjectsByCondition = cell(3,1);
for c = 1:3
    subjectsByCondition{c} = ...
        string(V{c}.Normatives.Kinematics.sujets(:));
end

uniqueSubjects = cellfun( ...
    @(x) unique(x,'stable'), ...
    subjectsByCondition, ...
    'UniformOutput', false);

if ~isequal(uniqueSubjects{1}, uniqueSubjects{2}, uniqueSubjects{3})
    error(['Norm_V1, Norm_V2 and Norm_V3 do not contain identical ' ...
        'participant sets in identical order.']);
end

nModelParticipants = numel(uniqueSubjects{1});

if nModelParticipants ~= 24
    warning('Expected 24 modelling participants but detected %d.', ...
        nModelParticipants);
end

% Use the Population structure stored in Norm_V1.
Population = V{1}.Population;

participantID = getPopulationVector( ...
    Population, {'subject_id','participant_id'});

participantName = getPopulationStringVector( ...
    Population, {'subject_name','name'});

ageYears = getStatData(Population, {'age'});
sexCode  = getStatData(Population, {'gender','sex_code'});
bodyMassKg = getStatData(Population, {'weight','body_mass'});
heightM = getStatData(Population, {'height'});

if hasAnyField(Population, {'BMI'})
    BMI = getStatData(Population, {'BMI'});
else
    BMI = bodyMassKg ./ (heightM.^2);
end

if hasAnyField(Population, {'L0','LL','leg_length'})
    lowerLimbLengthM = getStatData( ...
        Population, {'L0','LL','leg_length'});
else
    lowerLimbLengthM = heightM .* 0.53;
end

participantID = participantID(:);
participantName = participantName(:);
ageYears = ageYears(:);
sexCode = sexCode(:);
bodyMassKg = bodyMassKg(:);
heightM = heightM(:);
BMI = BMI(:);
lowerLimbLengthM = lowerLimbLengthM(:);

nDemographicRows = numel(participantID);

if nDemographicRows ~= nModelParticipants
    error(['Population demographics contain %d participants, while the ' ...
        'Norm files contain %d unique participants.'], ...
        nDemographicRows, nModelParticipants);
end

DemographicsRaw = table( ...
    participantID, ...
    participantName, ...
    ageYears, ...
    sexCode, ...
    categorical(sexCode,[0 1],{'Female','Male'}), ...
    bodyMassKg, ...
    heightM, ...
    BMI, ...
    lowerLimbLengthM, ...
    'VariableNames', { ...
        'ParticipantID', ...
        'ParticipantName', ...
        'Age_years', ...
        'SexCode', ...
        'Sex', ...
        'BodyMass_kg', ...
        'Height_m', ...
        'BMI_kg_m2', ...
        'EstimatedLowerLimbLength_m'});

%% ========================================================================
% 3. DERIVE PARTICIPANT FLOW FROM THE SOURCE WORKBOOK
% =========================================================================
speedSheet = readcell(sourceWorkbook, ...
    'Sheet', 'WalkingSpeeds', ...
    'UseExcel', false);

sourceSpeedIDs = numericIDsFromColumn(speedSheet(:,2));
nSpeedRoster = numel(unique(sourceSpeedIDs));

nExpectedTrials = nModelParticipants * 3 * 3;

%% ========================================================================
% 4. BUILD TRIAL-LEVEL TABLE FROM CLEAN CONDITION FILES
% =========================================================================
TrialData = table();

for c = 1:3

    S = load(cleanFiles{c});
    G = S.Normatives.Gaitparameters;

    pid = double(G.participant_id(:));
    trialID = string(G.trial_id(:));

    strideLengthM = double(G.stride_length.data(:));
    stepLengthM   = double(G.step_length.data(:));
    cadence       = double(G.cadence.data(:));
    stancePct     = double(G.stance_phase.data(:));
    swingPct      = double(G.swing_phase.data(:));
    speedMs       = double(G.mean_velocity.data(:));
    targetKmh     = double(G.target_speed_kmh.data(:));
    measuredKmh   = double(G.measured_speed_kmh.data(:));

    nRows = numel(pid);

    thisName = strings(nRows,1);
    thisLegLength = nan(nRows,1);

    for i = 1:nRows
        idx = find(participantID == pid(i),1,'first');
        if isempty(idx)
            error('Participant %d missing from Population metadata.',pid(i));
        end
        thisName(i) = participantName(idx);
        thisLegLength(i) = lowerLimbLengthM(idx);
    end

    froudeSpeed = speedMs ./ sqrt(9.81 .* thisLegLength);
    phaseSumPct = stancePct + swingPct;

    % Detect the exact source pattern that exposed the P23 problem:
    % a length in metres equals the measured speed value in km/h.
    strideEqualsSpeedKmh = abs(strideLengthM - measuredKmh) < 1e-12;

    qcStatus = repmat("Pass",nRows,1);
    qcReason = strings(nRows,1);

    for i = 1:nRows
        reasons = strings(0,1);

        if strideLengthM(i) > 2.0
            reasons(end+1) = "Stride length > 2.0 m"; %#ok<AGROW>
        end

        if stepLengthM(i) > 1.0
            reasons(end+1) = "Step length > 1.0 m"; %#ok<AGROW>
        end

        if cadence(i) < 60
            reasons(end+1) = "Cadence < 60 steps/min"; %#ok<AGROW>
        end

        if strideEqualsSpeedKmh(i)
            reasons(end+1) = ...
                "Stride length exactly equals measured speed in km/h"; %#ok<AGROW>
        end

        if ~isempty(reasons)
            qcStatus(i) = "Review";
            qcReason(i) = strjoin(reasons,'; ');
        end
    end

    Tc = table( ...
        trialID, ...
        pid, ...
        thisName, ...
        repmat(conditionCodes(c),nRows,1), ...
        repmat(conditionLabels(c),nRows,1), ...
        targetKmh, ...
        measuredKmh, ...
        speedMs, ...
        froudeSpeed, ...
        strideLengthM, ...
        stepLengthM, ...
        cadence, ...
        stancePct, ...
        swingPct, ...
        phaseSumPct, ...
        strideEqualsSpeedKmh, ...
        qcStatus, ...
        qcReason, ...
        'VariableNames', { ...
            'TrialID', ...
            'ParticipantID', ...
            'ParticipantName', ...
            'ConditionCode', ...
            'Condition', ...
            'TargetSpeed_kmh', ...
            'MeasuredSpeed_kmh', ...
            'MeasuredSpeed_m_s', ...
            'FroudeSpeed', ...
            'StrideLength_m', ...
            'StepLength_m', ...
            'Cadence_steps_min', ...
            'StancePhase_percent', ...
            'SwingPhase_percent', ...
            'PhaseSum_percent', ...
            'StrideEqualsSpeedKmh', ...
            'QCStatus', ...
            'QCReason'});

    TrialData = [TrialData; Tc]; %#ok<AGROW>
end

nAvailableTrials = height(TrialData);
nMissingTrials = nExpectedTrials - nAvailableTrials;

%% ========================================================================
% 5. AVERAGE THREE REPEATED TRIALS WITHIN PARTICIPANT AND CONDITION
% =========================================================================
ParticipantConditionMeans = table();

for p = 1:numel(participantID)
    for c = 1:3

        idx = TrialData.ParticipantID == participantID(p) & ...
            TrialData.ConditionCode == conditionCodes(c);

        nTrials = sum(idx);

        if nTrials == 0
            continue;
        end

        temp = table( ...
            participantID(p), ...
            participantName(p), ...
            conditionCodes(c), ...
            conditionLabels(c), ...
            nTrials, ...
            mean(TrialData.MeasuredSpeed_m_s(idx),'omitnan'), ...
            mean(TrialData.FroudeSpeed(idx),'omitnan'), ...
            mean(TrialData.StrideLength_m(idx),'omitnan'), ...
            mean(TrialData.StepLength_m(idx),'omitnan'), ...
            mean(TrialData.Cadence_steps_min(idx),'omitnan'), ...
            mean(TrialData.StancePhase_percent(idx),'omitnan'), ...
            mean(TrialData.SwingPhase_percent(idx),'omitnan'), ...
            any(TrialData.StrideEqualsSpeedKmh(idx)), ...
            'VariableNames', { ...
                'ParticipantID', ...
                'ParticipantName', ...
                'ConditionCode', ...
                'Condition', ...
                'TrialsAveraged', ...
                'WalkingSpeed_m_s', ...
                'FroudeSpeed', ...
                'StrideLength_m', ...
                'StepLength_m', ...
                'Cadence_steps_min', ...
                'StancePhase_percent', ...
                'SwingPhase_percent', ...
                'ContainsStrideSpeedMatch'});

        ParticipantConditionMeans = ...
            [ParticipantConditionMeans; temp]; %#ok<AGROW>
    end
end

%% ========================================================================
% 6. DEMOGRAPHIC SUMMARY
% =========================================================================
DemographicSummary = table();

DemographicSummary = appendContinuousSummary( ...
    DemographicSummary, ...
    "Age (years)", ...
    ageYears, ...
    "Mean ± SD; verify the participant aged below 18 against eligibility.");

DemographicSummary = appendContinuousSummary( ...
    DemographicSummary, ...
    "Height (m)", ...
    heightM, ...
    "Mean ± SD.");

DemographicSummary = appendContinuousSummary( ...
    DemographicSummary, ...
    "Body mass (kg)", ...
    bodyMassKg, ...
    "Inspect distribution; median [IQR] may be preferable if skewed.");

DemographicSummary = appendContinuousSummary( ...
    DemographicSummary, ...
    "BMI (kg/m^2)", ...
    BMI, ...
    "Inspect distribution; median [IQR] may be preferable if skewed.");

DemographicSummary = appendContinuousSummary( ...
    DemographicSummary, ...
    "Estimated lower-limb length (m)", ...
    lowerLimbLengthM, ...
    "Estimated as height × 0.53 unless directly measured elsewhere.");

nFemale = sum(sexCode == 0);
nMale   = sum(sexCode == 1);

SexSummary = table( ...
    ["Female";"Male"], ...
    [nFemale;nMale], ...
    100 .* [nFemale;nMale] ./ numel(sexCode), ...
    'VariableNames', {'Sex','N','Percent'});

%% ========================================================================
% 7. CONDITION-LEVEL DESCRIPTIVE STATISTICS
% =========================================================================
metricVariables = [ ...
    "WalkingSpeed_m_s"
    "FroudeSpeed"
    "StrideLength_m"
    "StepLength_m"
    "Cadence_steps_min"
    "StancePhase_percent"
    "SwingPhase_percent"];

metricLabels = [ ...
    "Walking speed (m/s)"
    "Froude speed (dimensionless)"
    "Stride length (m)"
    "Step length (m)"
    "Cadence (steps/min)"
    "Stance phase (% gait cycle)"
    "Swing phase (% gait cycle)"];

DescriptivesAll = table();
DescriptivesQC = table();

% Present in slow-normal-fast order.
reportOrder = ["Slow";"Normal";"Fast"];

for c = 1:numel(reportOrder)
    condition = reportOrder(c);

    for m = 1:numel(metricVariables)

        variableName = metricVariables(m);
        metricLabel = metricLabels(m);

        idxAll = ParticipantConditionMeans.Condition == condition;
        valuesAll = ParticipantConditionMeans.(variableName)(idxAll);

        DescriptivesAll = appendConditionSummary( ...
            DescriptivesAll, ...
            condition, ...
            metricLabel, ...
            valuesAll, ...
            "");

        % QC rule:
        % Only stride-derived variables are provisionally affected when a
        % participant-condition contains the exact stride/speed duplicate.
        idxQC = idxAll;
        qcNote = "";

        isStrideDerived = any(variableName == [ ...
            "StrideLength_m", ...
            "StepLength_m", ...
            "Cadence_steps_min"]);

        if isStrideDerived
            idxQC = idxAll & ...
                ~ParticipantConditionMeans.ContainsStrideSpeedMatch;

            if sum(idxQC) < sum(idxAll)
                qcNote = ...
                    "Participant-condition with exact stride/speed match omitted pending source correction";
            end
        end

        valuesQC = ParticipantConditionMeans.(variableName)(idxQC);

        DescriptivesQC = appendConditionSummary( ...
            DescriptivesQC, ...
            condition, ...
            metricLabel, ...
            valuesQC, ...
            qcNote);
    end
end

%% ========================================================================
% 8. WAVEFORM COMPLETENESS
% =========================================================================
WaveformCompleteness = table();

jointCodes = ["FE2";"FE3";"FE4"];
jointNames = ["Ankle";"Knee";"Hip"];

for c = 1:3
    K = V{c}.Normatives.Kinematics;

    for j = 1:numel(jointCodes)
        data = double(K.(jointCodes(j)).data);

        temp = table( ...
            conditionLabels(c), ...
            jointNames(j), ...
            size(data,2), ...
            size(data,1), ...
            sum(isnan(data),'all'), ...
            string(ternary(sum(isnan(data),'all') == 0, ...
                'Complete','Missing values present')), ...
            'VariableNames', { ...
                'Condition', ...
                'Joint', ...
                'AvailableCurves', ...
                'PointsPerCurve', ...
                'MissingValues', ...
                'Status'});

        WaveformCompleteness = ...
            [WaveformCompleteness; temp]; %#ok<AGROW>
    end
end

%% ========================================================================
% 9. PARTICIPANT FLOW AND SUBSTITUTION TRACEABILITY
% =========================================================================
% The clean script substitutes target speed when measured speed is missing,
% but it does not store a separate substitution flag. Exact equality between
% target and measured speed is therefore not proof that substitution occurred.

nMeasuredMissingAfterCleaning = ...
    sum(~isfinite(TrialData.MeasuredSpeed_kmh));

ParticipantFlow = table( ...
    [ ...
        "Recruited participants"
        "People in source walking-speed roster"
        "Complete waveform-model participants"
        "Expected waveform-model trials"
        "Available waveform-model trials"
        "Missing waveform-model trials"
        "Measured speeds missing after cleaning"
        "Confirmed measured-speed substitutions"], ...
    [ ...
        nRecruitedReported
        nSpeedRoster
        nModelParticipants
        nExpectedTrials
        nAvailableTrials
        nMissingTrials
        nMeasuredMissingAfterCleaning
        NaN], ...
    [ ...
        "Previously reported"
        "Computed from WalkingSpeeds participant IDs"
        "Computed from the common Norm-file participant set"
        "24 participants × 3 conditions × 3 trials"
        "Computed from clean MAT files"
        "Expected minus available"
        "Computed from clean MAT files"
        "Not reconstructable from current clean files"], ...
    'VariableNames', {'PopulationStage','N','Evidence'});

%% ========================================================================
% 10. P23 AUDIT TABLE FROM THE ORIGINAL WORKBOOK
% =========================================================================
P23Audit = buildP23Audit(sourceWorkbook);

%% ========================================================================
% 11. EXPORT RESULTS
% =========================================================================
writetable(ParticipantFlow, outputWorkbook, 'Sheet', 'Participant Flow');
writetable(DemographicSummary, outputWorkbook, 'Sheet', 'Demographic Summary');
writetable(SexSummary, outputWorkbook, 'Sheet', 'Sex Summary');
writetable(DemographicsRaw, outputWorkbook, 'Sheet', 'Demographics Raw');
writetable(TrialData, outputWorkbook, 'Sheet', 'Trial Data QC');
writetable(ParticipantConditionMeans, outputWorkbook, ...
    'Sheet', 'Participant Means');
writetable(DescriptivesAll, outputWorkbook, ...
    'Sheet', 'Descriptives All');
writetable(DescriptivesQC, outputWorkbook, ...
    'Sheet', 'Descriptives QC');
writetable(WaveformCompleteness, outputWorkbook, ...
    'Sheet', 'Waveform Completeness');
writetable(P23Audit, outputWorkbook, 'Sheet', 'P23 Source Audit');

% CSV exports
writetable(ParticipantFlow, ...
    fullfile(outputDir,'Participant_Flow.csv'));
writetable(DemographicSummary, ...
    fullfile(outputDir,'Demographic_Summary.csv'));
writetable(SexSummary, ...
    fullfile(outputDir,'Sex_Summary.csv'));
writetable(DemographicsRaw, ...
    fullfile(outputDir,'Demographics_Raw.csv'));
writetable(TrialData, ...
    fullfile(outputDir,'Trial_Data_QC.csv'));
writetable(ParticipantConditionMeans, ...
    fullfile(outputDir,'Participant_Condition_Means.csv'));
writetable(DescriptivesAll, ...
    fullfile(outputDir,'Spatiotemporal_Descriptives_All.csv'));
writetable(DescriptivesQC, ...
    fullfile(outputDir,'Spatiotemporal_Descriptives_QC.csv'));
writetable(WaveformCompleteness, ...
    fullfile(outputDir,'Waveform_Completeness.csv'));
writetable(P23Audit, ...
    fullfile(outputDir,'P23_Source_Audit.csv'));

%% ========================================================================
% 12. CONSOLE SUMMARY
% =========================================================================
fprintf('\n============================================================\n');
fprintf('DESCRIPTIVE STATISTICS COMPLETE\n');
fprintf('============================================================\n');
fprintf('Source speed roster: %d participants\n', nSpeedRoster);
fprintf('Waveform model:      %d participants\n', nModelParticipants);
fprintf('Available trials:    %d of %d\n', ...
    nAvailableTrials, nExpectedTrials);
fprintf('Female: %d (%.1f%%)\n', nFemale, 100*nFemale/numel(sexCode));
fprintf('Male:   %d (%.1f%%)\n', nMale, 100*nMale/numel(sexCode));

fprintf('\nP23 exact stride/speed duplicate rows:\n');
disp(P23Audit(P23Audit.ExactNumericalMatch,:));

fprintf('\nOutputs saved in:\n  %s\n', outputDir);
fprintf('Main workbook:\n  %s\n', outputWorkbook);

end

%% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function values = getPopulationVector(Population, candidateFields)
fieldName = firstExistingField(Population, candidateFields);
values = double(Population.(fieldName));
end

function values = getPopulationStringVector(Population, candidateFields)
fieldName = firstExistingField(Population, candidateFields);
values = string(Population.(fieldName));
end

function values = getStatData(Population, candidateFields)
fieldName = firstExistingField(Population, candidateFields);
S = Population.(fieldName);

if isstruct(S) && isfield(S,'data')
    values = double(S.data);
else
    values = double(S);
end
end

function tf = hasAnyField(S, candidateFields)
tf = false;
for i = 1:numel(candidateFields)
    if isfield(S,candidateFields{i})
        tf = true;
        return;
    end
end
end

function fieldName = firstExistingField(S, candidateFields)
fieldName = '';
for i = 1:numel(candidateFields)
    if isfield(S,candidateFields{i})
        fieldName = candidateFields{i};
        return;
    end
end

error('None of the expected fields were found: %s', ...
    strjoin(candidateFields,', '));
end

function IDs = numericIDsFromColumn(columnCells)
IDs = [];
for i = 1:numel(columnCells)
    value = columnCells{i};
    if isnumeric(value) && isscalar(value) && isfinite(value)
        IDs(end+1,1) = double(value); %#ok<AGROW>
    end
end
end

function T = appendContinuousSummary(T, characteristic, values, note)
values = values(isfinite(values));

n = numel(values);
meanValue = mean(values);
sdValue = std(values,0);
medianValue = median(values);
q1 = prctile(values,25);
q3 = prctile(values,75);
minValue = min(values);
maxValue = max(values);

temp = table( ...
    string(characteristic), ...
    n, ...
    meanValue, ...
    sdValue, ...
    medianValue, ...
    q1, ...
    q3, ...
    minValue, ...
    maxValue, ...
    string(note), ...
    'VariableNames', { ...
        'Characteristic', ...
        'N', ...
        'Mean', ...
        'SD', ...
        'Median', ...
        'Q1', ...
        'Q3', ...
        'Minimum', ...
        'Maximum', ...
        'ReportingNote'});

T = [T; temp];
end

function T = appendConditionSummary(T, condition, metric, values, note)
values = values(isfinite(values));

n = numel(values);

if n == 0
    meanValue = NaN;
    sdValue = NaN;
    medianValue = NaN;
    q1 = NaN;
    q3 = NaN;
    minValue = NaN;
    maxValue = NaN;
else
    meanValue = mean(values);
    sdValue = std(values,0);
    medianValue = median(values);
    q1 = prctile(values,25);
    q3 = prctile(values,75);
    minValue = min(values);
    maxValue = max(values);
end

temp = table( ...
    string(condition), ...
    string(metric), ...
    n, ...
    meanValue, ...
    sdValue, ...
    medianValue, ...
    q1, ...
    q3, ...
    minValue, ...
    maxValue, ...
    string(note), ...
    'VariableNames', { ...
        'Condition', ...
        'Metric', ...
        'NParticipants', ...
        'Mean', ...
        'SD', ...
        'Median', ...
        'Q1', ...
        'Q3', ...
        'Minimum', ...
        'Maximum', ...
        'QCNote'});

T = [T; temp];
end

function P23Audit = buildP23Audit(sourceWorkbook)
spatio = readcell(sourceWorkbook, ...
    'Sheet', 'Spatiotemporal', ...
    'UseExcel', false);

speeds = readcell(sourceWorkbook, ...
    'Sheet', 'WalkingSpeeds', ...
    'UseExcel', false);

participantID = 23;
spatioRow = findNumericID(spatio(:,2),participantID);
speedRow  = findNumericID(speeds(:,2),participantID);

if isempty(spatioRow) || isempty(speedRow)
    error('P23 could not be found in both source sheets.');
end

trialLabels = [ ...
    "C1_T1"; "C1_T2"; "C1_T3"; ...
    "C2_T1"; "C2_T2"; "C2_T3"; ...
    "C3_T1"; "C3_T2"; "C3_T3"];

spatioCols = [3 4 5 7 8 9 11 12 13];
speedCols  = [13 14 15 17 18 19 21 22 23];

strideLengthM = cellVectorToDouble( ...
    spatio(spatioRow,spatioCols));

measuredSpeedKmh = cellVectorToDouble( ...
    speeds(speedRow,speedCols));

exactMatch = abs(strideLengthM - measuredSpeedKmh) < 1e-12;

spatioCell = strings(numel(spatioCols),1);
speedCell = strings(numel(speedCols),1);

for i = 1:numel(spatioCols)
    spatioCell(i) = ...
        columnNumberToName(spatioCols(i)) + string(spatioRow);
    speedCell(i) = ...
        columnNumberToName(speedCols(i)) + string(speedRow);
end

P23Audit = table( ...
    repmat(participantID,numel(trialLabels),1), ...
    repmat(string(spatio{spatioRow,1}),numel(trialLabels),1), ...
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
end

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

function output = ternary(condition,trueValue,falseValue)
if condition
    output = trueValue;
else
    output = falseValue;
end
end
