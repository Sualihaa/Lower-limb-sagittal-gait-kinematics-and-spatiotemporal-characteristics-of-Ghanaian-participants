function run_gait_descriptive_statistics_LITERATURE_ALIGNED
% =========================================================================
% LITERATURE-ALIGNED DESCRIPTIVE STATISTICS AND DATA-INTEGRITY AUDIT
% =========================================================================
%
% Purpose
% -------
% Reproduce participant-flow, demographic, spatiotemporal and waveform-
% completeness summaries for the gait dataset while:
%
%   1. treating the participant as the independent statistical unit;
%   2. averaging repeated trials within participant and condition before
%      calculating group descriptive statistics;
%   3. reporting both mean/SD and median/IQR rather than selecting a
%      summary automatically from a normality-test p-value;
%   4. reporting missingness and analysis-specific denominators;
%   5. preserving raw values and logging every exclusion;
%   6. excluding only outcomes directly affected by a documented source-
%      data inconsistency;
%   7. using precise dimensionless-speed and Froude-number terminology;
%   8. exporting the methodological references with the results.
%
% This script does NOT:
%   - run hypothesis tests;
%   - treat repeated trials as independent participants;
%   - use arbitrary gait-value thresholds as automatic exclusion rules;
%   - delete raw records;
%   - impute missing demographic, spatiotemporal or waveform values.
%
% REQUIRED INPUT FILES
% --------------------
% Put these files in the same folder as this script, or edit inputDir:
%
%   Project FYP (Alpha)(1)(1).xlsx
%   Norm_V1.mat
%   Norm_V2.mat
%   Norm_V3.mat
%   dataNorm_C1_clean.mat
%   dataNorm_C2_clean.mat
%   dataNorm_C3_clean.mat
%
% OUTPUT
% ------
%   Statistics_Literature_Aligned/
%       Gait_Descriptive_Statistics_LITERATURE_ALIGNED.xlsx
%       CSV tables
%       Distribution_Diagnostics/*.png
%
% PRIMARY METHODOLOGICAL REFERENCES
% ---------------------------------
% [1] Scientific Data. Submission Guidelines: Data Descriptor, Data
%     Overview and Technical Validation.
%     https://www.nature.com/sdata/publish/submission-guidelines
%
% [2] Lang TA, Altman DG. Basic statistical reporting for articles
%     published in biomedical journals: the SAMPL Guidelines.
%     Int J Nurs Stud. 2015;52(1):5-9.
%     https://doi.org/10.1016/j.ijnurstu.2014.09.006
%
% [3] Lazic SE. The problem of pseudoreplication in neuroscientific
%     studies: is it affecting your analysis?
%     BMC Neurosci. 2010;11:5.
%     https://doi.org/10.1186/1471-2202-11-5
%
% [4] Ghasemi A, Zahediasl S. Normality tests for statistical analysis:
%     a guide for non-statisticians.
%     Int J Endocrinol Metab. 2012;10(2):486-489.
%     https://doi.org/10.5812/ijem.3505
%
% [5] Lee KJ, et al. Framework for the treatment and reporting of missing
%     data in observational studies: the TARMOS framework.
%     J Clin Epidemiol. 2021;134:79-88.
%     https://doi.org/10.1016/j.jclinepi.2021.01.008
%
% [6] Alexander RM, Jayes AS. A dynamic similarity hypothesis for the
%     gaits of quadrupedal mammals.
%     J Zool. 1983;201:135-152.
%     https://doi.org/10.1111/j.1469-7998.1983.tb04266.x
%
% [7] Chehab EF, Andriacchi TP, Favre J. Speed, age, sex, and body mass
%     index provide a rigorous basis for comparing the kinematic and
%     kinetic profiles of the lower extremity during walking.
%     J Biomech. 2017;58:11-20.
%     https://doi.org/10.1016/j.jbiomech.2017.04.014
%
% [8] Moissenet F, Leboeuf F, Armand S. Lower limb sagittal gait
%     kinematics can be predicted based on walking speed, gender, age
%     and BMI. Sci Rep. 2019;9:9510.
%     https://doi.org/10.1038/s41598-019-45397-4
%
% Run
% ---
%   run_gait_descriptive_statistics_LITERATURE_ALIGNED
%
% =========================================================================

clear;
clc;

%% ========================================================================
% 1. PRE-SPECIFIED ANALYSIS SETTINGS
% =========================================================================
scriptDir = fileparts(mfilename('fullpath'));
inputDir = scriptDir;

sourceWorkbook = fullfile(inputDir, ...
    'Project FYP (Alpha)(1).xlsx');

normFiles = {
    fullfile(inputDir,'Norm_V1.mat')
    fullfile(inputDir,'Norm_V2.mat')
    fullfile(inputDir,'Norm_V3.mat')
    };

cleanFiles = {
    fullfile(inputDir,'dataNorm_C1_clean.mat')
    fullfile(inputDir,'dataNorm_C2_clean.mat')
    fullfile(inputDir,'dataNorm_C3_clean.mat')
    };

conditionCodes = ["C1";"C2";"C3"];
conditionLabels = ["Normal";"Slow";"Fast"];

% Participant is the independent statistical unit [3].
requiredTrialsPerParticipantCondition = 3;

% Retain raw records even when excluded from a specific derived summary.
preserveRawRecords = true;

% Generate histograms and Q-Q plots when the required MATLAB function is
% available. Graphical assessment is used as supporting information; no
% normality-test p-value automatically determines the reported summary [4].
generateDistributionFigures = true;

% Previously reported recruitment number. It cannot be reconstructed from
% the supplied MAT files, so it is explicitly labelled as user-supplied.
nRecruitedReported = 30;

outputDir = fullfile(scriptDir,'Statistics_Literature_Aligned');
figureDir = fullfile(outputDir,'Distribution_Diagnostics');

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

if generateDistributionFigures && ~exist(figureDir,'dir')
    mkdir(figureDir);
end

outputWorkbook = fullfile(outputDir, ...
    'Gait_Descriptive_Statistics_LITERATURE_ALIGNED.xlsx');

if isfile(outputWorkbook)
    delete(outputWorkbook);
end

requiredFiles = [{sourceWorkbook}; normFiles; cleanFiles];

for i = 1:numel(requiredFiles)
    if ~isfile(requiredFiles{i})
        error('Required input file not found: %s',requiredFiles{i});
    end
end

fprintf('\n============================================================\n');
fprintf('LITERATURE-ALIGNED GAIT STATISTICS\n');
fprintf('Started: %s\n',datestr(now));
fprintf('============================================================\n');

%% ========================================================================
% 2. LOAD AND VERIFY THE THREE CONDITION FILES
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
    'UniformOutput',false);

if ~isequal(uniqueSubjects{1},uniqueSubjects{2},uniqueSubjects{3})
    error(['Norm_V1, Norm_V2 and Norm_V3 do not contain identical ' ...
        'participant sets in identical order.']);
end

nModelParticipants = numel(uniqueSubjects{1});

% Use participant metadata stored in Norm_V1.
Population = V{1}.Population;

participantID = getPopulationVector( ...
    Population,{'subject_id','participant_id'});

participantName = getPopulationStringVector( ...
    Population,{'subject_name','name'});

ageYears = getStatData(Population,{'age'});
sexCode = getStatData(Population,{'gender','sex_code'});
bodyMassKg = getStatData(Population,{'weight','body_mass'});
heightM = getStatData(Population,{'height'});

if hasAnyField(Population,{'BMI'})
    BMI = getStatData(Population,{'BMI'});
else
    BMI = bodyMassKg ./ (heightM.^2);
end

if hasAnyField(Population,{'L0','LL','leg_length'})
    lowerLimbLengthM = getStatData( ...
        Population,{'L0','LL','leg_length'});
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

if numel(participantID) ~= nModelParticipants
    error(['Population metadata contain %d participants, whereas the ' ...
        'Norm files contain %d unique participants.'], ...
        numel(participantID),nModelParticipants);
end

if numel(unique(participantID)) ~= numel(participantID)
    error('Duplicate participant IDs were detected in Population metadata.');
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
    'VariableNames',{ ...
        'ParticipantID', ...
        'ParticipantName', ...
        'Age_years', ...
        'SexCode', ...
        'Sex', ...
        'BodyMass_kg', ...
        'Height_m', ...
        'BMI_kg_m2', ...
        'LowerLimbLength_m'});

%% ========================================================================
% 3. AUDIT SOURCE SPEEDS AND FALLBACK SUBSTITUTIONS
% =========================================================================
% TARMOS and SAMPL support explicit accounting of missing values and the
% method used to handle them [2,5].
%
% The clean-data builder uses target speed only when measured speed is
% missing. This audit reconstructs that decision directly from the source
% workbook rather than inferring substitution from target==measured.

SpeedSourceAudit = buildSpeedSourceAudit( ...
    sourceWorkbook, ...
    participantID, ...
    participantName, ...
    conditionCodes, ...
    conditionLabels);

nSpeedRoster = numel(unique( ...
    SpeedSourceAudit.AllSourceRosterParticipantID( ...
    isfinite(SpeedSourceAudit.AllSourceRosterParticipantID))));

nMeasuredSpeedSubstitutions = ...
    sum(SpeedSourceAudit.MeasuredSpeedMissingInSource);

%% ========================================================================
% 4. AUDIT SOURCE CROSS-VARIABLE CONSISTENCY
% =========================================================================
% No literature-derived physiological cut-offs are used to exclude records.
%
% Instead, a source-data inconsistency is identified when the complete
% three-trial stride-length vector in metres is numerically identical to
% the complete three-trial measured-speed vector in km/h for the same
% participant and condition.
%
% This is an internal provenance/consistency check. It is not a normative
% gait threshold and is not presented as one.

SourceConsistencyAudit = buildSourceConsistencyAudit( ...
    sourceWorkbook, ...
    participantID, ...
    participantName, ...
    conditionCodes, ...
    conditionLabels);

%% ========================================================================
% 5. BUILD TRIAL-LEVEL ANALYSIS TABLE
% =========================================================================
TrialData = table();

for c = 1:3

    S = load(cleanFiles{c});
    G = S.Normatives.Gaitparameters;

    pid = double(G.participant_id(:));
    trialID = string(G.trial_id(:));

    strideLengthM = double(G.stride_length.data(:));
    stepLengthM = double(G.step_length.data(:));
    cadence = double(G.cadence.data(:));
    stancePct = double(G.stance_phase.data(:));
    swingPct = double(G.swing_phase.data(:));
    speedMs = double(G.mean_velocity.data(:));
    targetKmh = double(G.target_speed_kmh.data(:));
    measuredKmh = double(G.measured_speed_kmh.data(:));

    nRows = numel(pid);

    if any([ ...
            numel(trialID), ...
            numel(strideLengthM), ...
            numel(stepLengthM), ...
            numel(cadence), ...
            numel(stancePct), ...
            numel(swingPct), ...
            numel(speedMs), ...
            numel(targetKmh), ...
            numel(measuredKmh)] ~= nRows)

        error('Condition %s contains inconsistent trial-vector lengths.', ...
            conditionCodes(c));
    end

    thisName = strings(nRows,1);
    thisLegLength = nan(nRows,1);
    measuredMissingInSource = false(nRows,1);
    targetFallbackExpected = false(nRows,1);
    cleanSpeedTraceMatchesSource = false(nRows,1);
    sourceVectorDuplicate = false(nRows,1);

    for i = 1:nRows

        demographicIndex = find(participantID == pid(i),1,'first');

        if isempty(demographicIndex)
            error('Participant %d is absent from Population metadata.',pid(i));
        end

        thisName(i) = participantName(demographicIndex);
        thisLegLength(i) = lowerLimbLengthM(demographicIndex);

        speedIndex = find( ...
            SpeedSourceAudit.TrialID == trialID(i), ...
            1,'first');

        if isempty(speedIndex)
            error('Trial %s is absent from the source speed audit.',trialID(i));
        end

        measuredMissingInSource(i) = ...
            SpeedSourceAudit.MeasuredSpeedMissingInSource(speedIndex);

        targetFallbackExpected(i) = ...
            SpeedSourceAudit.TargetFallbackExpected(speedIndex);

        expectedUsedKmh = ...
            SpeedSourceAudit.ExpectedSpeedUsedByCleaner_kmh(speedIndex);

        cleanSpeedTraceMatchesSource(i) = ...
            finiteEqual(measuredKmh(i),expectedUsedKmh,1e-12);

        consistencyIndex = find( ...
            SourceConsistencyAudit.ParticipantID == pid(i) & ...
            SourceConsistencyAudit.ConditionCode == conditionCodes(c), ...
            1,'first');

        if isempty(consistencyIndex)
            error(['Participant %d condition %s is absent from the ' ...
                'source consistency audit.'],pid(i),conditionCodes(c));
        end

        sourceVectorDuplicate(i) = ...
            SourceConsistencyAudit.ThreeTrialVectorExactDuplicate( ...
            consistencyIndex);
    end

    % Precise terminology:
    % dimensionless speed = v/sqrt(gL)
    % Froude number       = v^2/(gL) [6]
    dimensionlessSpeed = speedMs ./ sqrt(9.81 .* thisLegLength);
    froudeNumber = (speedMs.^2) ./ (9.81 .* thisLegLength);

    phaseSumPct = stancePct + swingPct;

    missingAnyPrimaryVariable = ...
        ~isfinite(speedMs) | ...
        ~isfinite(strideLengthM) | ...
        ~isfinite(stepLengthM) | ...
        ~isfinite(cadence) | ...
        ~isfinite(stancePct) | ...
        ~isfinite(swingPct);

    dataIntegrityStatus = repmat("Pass",nRows,1);
    dataIntegrityReason = strings(nRows,1);

    for i = 1:nRows
        reasons = strings(0,1);

        if missingAnyPrimaryVariable(i)
            reasons(end+1) = ...
                "One or more primary trial variables are missing/non-finite"; %#ok<AGROW>
        end

        if ~cleanSpeedTraceMatchesSource(i)
            reasons(end+1) = ...
                "Clean measured-speed value does not match the source/fallback audit"; %#ok<AGROW>
        end

        if sourceVectorDuplicate(i)
            reasons(end+1) = ...
                "Three-trial stride vector duplicates measured-speed vector across different units"; %#ok<AGROW>
        end

        if ~isempty(reasons)
            dataIntegrityStatus(i) = "Review";
            dataIntegrityReason(i) = strjoin(reasons,'; ');
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
        dimensionlessSpeed, ...
        froudeNumber, ...
        strideLengthM, ...
        stepLengthM, ...
        cadence, ...
        stancePct, ...
        swingPct, ...
        phaseSumPct, ...
        measuredMissingInSource, ...
        targetFallbackExpected, ...
        cleanSpeedTraceMatchesSource, ...
        sourceVectorDuplicate, ...
        missingAnyPrimaryVariable, ...
        dataIntegrityStatus, ...
        dataIntegrityReason, ...
        'VariableNames',{ ...
            'TrialID', ...
            'ParticipantID', ...
            'ParticipantName', ...
            'ConditionCode', ...
            'Condition', ...
            'TargetSpeed_kmh', ...
            'MeasuredSpeedUsed_kmh', ...
            'MeasuredSpeedUsed_m_s', ...
            'DimensionlessSpeed_v_over_sqrt_gL', ...
            'FroudeNumber_v2_over_gL', ...
            'StrideLength_m', ...
            'StepLength_m', ...
            'Cadence_steps_min', ...
            'StancePhase_percent', ...
            'SwingPhase_percent', ...
            'PhaseSum_percent', ...
            'MeasuredSpeedMissingInSource', ...
            'TargetFallbackExpected', ...
            'CleanSpeedTraceMatchesSource', ...
            'SourceVectorDuplicate', ...
            'MissingAnyPrimaryVariable', ...
            'DataIntegrityStatus', ...
            'DataIntegrityReason'});

    TrialData = [TrialData; Tc]; %#ok<AGROW>
end

nExpectedTrials = ...
    nModelParticipants * numel(conditionCodes) * ...
    requiredTrialsPerParticipantCondition;

nAvailableTrials = height(TrialData);
nMissingTrials = nExpectedTrials - nAvailableTrials;

if nMissingTrials < 0
    error('Available trials exceed the pre-specified expected count.');
end

%% ========================================================================
% 6. TRIAL-LEVEL MISSINGNESS SUMMARY
% =========================================================================
% Analysis-specific denominators and missing counts are reported [2,5].

MissingnessSummary = buildMissingnessSummary(TrialData);

%% ========================================================================
% 7. PARTICIPANT-CONDITION MEANS
% =========================================================================
% Repeated trials are first averaged within participant and condition so
% that the participant—not the trial—is the unit contributing to group
% descriptive statistics [3].
%
% Completeness is assessed separately for every variable. A missing stride
% value, for example, does not remove an otherwise complete walking-speed
% or stance-phase value from the descriptive analysis [5].

ParticipantConditionMeans = table();

for p = 1:numel(participantID)

    for c = 1:numel(conditionCodes)

        idx = TrialData.ParticipantID == participantID(p) & ...
            TrialData.ConditionCode == conditionCodes(c);

        nTrials = sum(idx);

        if nTrials == 0
            continue;
        end

        sourceVectorDuplicate = ...
            any(TrialData.SourceVectorDuplicate(idx));

        walkingSpeedValues = ...
            TrialData.MeasuredSpeedUsed_m_s(idx);

        dimensionlessSpeedValues = ...
            TrialData.DimensionlessSpeed_v_over_sqrt_gL(idx);

        froudeNumberValues = ...
            TrialData.FroudeNumber_v2_over_gL(idx);

        strideValues = TrialData.StrideLength_m(idx);
        stepValues = TrialData.StepLength_m(idx);
        cadenceValues = TrialData.Cadence_steps_min(idx);
        stanceValues = TrialData.StancePhase_percent(idx);
        swingValues = TrialData.SwingPhase_percent(idx);

        temp = table( ...
            participantID(p), ...
            participantName(p), ...
            conditionCodes(c), ...
            conditionLabels(c), ...
            nTrials, ...
            nTrials == requiredTrialsPerParticipantCondition, ...
            mean(walkingSpeedValues,'omitnan'), ...
            sum(isfinite(walkingSpeedValues)), ...
            mean(dimensionlessSpeedValues,'omitnan'), ...
            sum(isfinite(dimensionlessSpeedValues)), ...
            mean(froudeNumberValues,'omitnan'), ...
            sum(isfinite(froudeNumberValues)), ...
            mean(strideValues,'omitnan'), ...
            sum(isfinite(strideValues)), ...
            mean(stepValues,'omitnan'), ...
            sum(isfinite(stepValues)), ...
            mean(cadenceValues,'omitnan'), ...
            sum(isfinite(cadenceValues)), ...
            mean(stanceValues,'omitnan'), ...
            sum(isfinite(stanceValues)), ...
            mean(swingValues,'omitnan'), ...
            sum(isfinite(swingValues)), ...
            sourceVectorDuplicate, ...
            'VariableNames',{ ...
                'ParticipantID', ...
                'ParticipantName', ...
                'ConditionCode', ...
                'Condition', ...
                'TrialsPresent', ...
                'CompleteThreeTrialRowSet', ...
                'WalkingSpeed_m_s', ...
                'NWalkingSpeedTrials', ...
                'DimensionlessSpeed_v_over_sqrt_gL', ...
                'NDimensionlessSpeedTrials', ...
                'FroudeNumber_v2_over_gL', ...
                'NFroudeNumberTrials', ...
                'StrideLength_m', ...
                'NStrideTrials', ...
                'StepLength_m', ...
                'NStepTrials', ...
                'Cadence_steps_min', ...
                'NCadenceTrials', ...
                'StancePhase_percent', ...
                'NStanceTrials', ...
                'SwingPhase_percent', ...
                'NSwingTrials', ...
                'SourceVectorDuplicate'});

        ParticipantConditionMeans = ...
            [ParticipantConditionMeans; temp]; %#ok<AGROW>
    end
end

%% ========================================================================
% 8. DEMOGRAPHIC SUMMARY
% =========================================================================
% Both mean/SD and median/IQR are exported [2].
% The final manuscript choice should consider graphical distribution
% assessment and scientific interpretation rather than a single automated
% normality-test decision [4].

DemographicSummary = table();

DemographicSummary = appendContinuousSummary( ...
    DemographicSummary, ...
    "Age (years)", ...
    ageYears, ...
    "Inspect distribution figure; verify protocol eligibility separately.");

DemographicSummary = appendContinuousSummary( ...
    DemographicSummary, ...
    "Height (m)", ...
    heightM, ...
    "Report analysis-specific N.");

DemographicSummary = appendContinuousSummary( ...
    DemographicSummary, ...
    "Body mass (kg)", ...
    bodyMassKg, ...
    "Choose mean/SD or median/IQR after graphical assessment.");

DemographicSummary = appendContinuousSummary( ...
    DemographicSummary, ...
    "BMI (kg/m^2)", ...
    BMI, ...
    "Choose mean/SD or median/IQR after graphical assessment.");

DemographicSummary = appendContinuousSummary( ...
    DemographicSummary, ...
    "Lower-limb length (m)", ...
    lowerLimbLengthM, ...
    "State clearly whether measured or estimated.");

nFemale = sum(sexCode == 0);
nMale = sum(sexCode == 1);
nOtherOrMissingSex = sum(~ismember(sexCode,[0 1]));

SexSummary = table( ...
    ["Female";"Male";"Other/missing"], ...
    [nFemale;nMale;nOtherOrMissingSex], ...
    100 .* [nFemale;nMale;nOtherOrMissingSex] ./ numel(sexCode), ...
    'VariableNames',{'Sex','N','Percent'});

%% ========================================================================
% 9. CONDITION-LEVEL DESCRIPTIVE STATISTICS
% =========================================================================
metricVariables = [ ...
    "WalkingSpeed_m_s"
    "DimensionlessSpeed_v_over_sqrt_gL"
    "FroudeNumber_v2_over_gL"
    "StrideLength_m"
    "StepLength_m"
    "Cadence_steps_min"
    "StancePhase_percent"
    "SwingPhase_percent"];

metricLabels = [ ...
    "Walking speed (m/s)"
    "Dimensionless speed v/sqrt(gL)"
    "Froude number v^2/(gL)"
    "Stride length (m)"
    "Step length (m)"
    "Cadence (steps/min)"
    "Stance phase (% gait cycle)"
    "Swing phase (% gait cycle)"];

metricCountVariables = [ ...
    "NWalkingSpeedTrials"
    "NDimensionlessSpeedTrials"
    "NFroudeNumberTrials"
    "NStrideTrials"
    "NStepTrials"
    "NCadenceTrials"
    "NStanceTrials"
    "NSwingTrials"];

% Raw descriptives preserve every participant-condition mean.
DescriptivesRaw = table();

% Main analysis descriptives:
% - require a complete three-trial set;
% - require finite data for the variable;
% - exclude source-duplicated participant-condition rows ONLY from stride,
%   step and cadence, because those are the directly affected outcomes;
% - retain walking speed, dimensionless speed, Froude number, stance and
%   swing for the same participant-condition when those variables are valid.
DescriptivesAnalysis = table();

reportOrder = ["Slow";"Normal";"Fast"];

for c = 1:numel(reportOrder)

    condition = reportOrder(c);

    for m = 1:numel(metricVariables)

        variableName = metricVariables(m);
        metricLabel = metricLabels(m);

        idxCondition = ...
            ParticipantConditionMeans.Condition == condition;

        rawValues = ...
            ParticipantConditionMeans.(variableName)(idxCondition);

        DescriptivesRaw = appendConditionSummary( ...
            DescriptivesRaw, ...
            condition, ...
            metricLabel, ...
            rawValues, ...
            "Raw participant-condition means; no data-integrity exclusion.");

        countVariableName = metricCountVariables(m);

        % Main descriptive analysis requires all three pre-specified trial
        % values for the variable currently being summarized. This is
        % outcome-specific complete-record handling [5].
        idxAnalysis = idxCondition & ...
            ParticipantConditionMeans.TrialsPresent == ...
                requiredTrialsPerParticipantCondition & ...
            ParticipantConditionMeans.(countVariableName) == ...
                requiredTrialsPerParticipantCondition;

        isStrideDerived = any(variableName == [ ...
            "StrideLength_m", ...
            "StepLength_m", ...
            "Cadence_steps_min"]);

        analysisNote = ...
            "Participant is the statistical unit; three valid trial values averaged for this metric.";

        if isStrideDerived
            nBefore = sum(idxAnalysis);

            idxAnalysis = idxAnalysis & ...
                ~ParticipantConditionMeans.SourceVectorDuplicate;

            nRemoved = nBefore - sum(idxAnalysis);

            if nRemoved > 0
                analysisNote = analysisNote + ...
                    " Source-duplicated participant-condition excluded for this affected outcome only.";
            end
        end

        analysisValues = ...
            ParticipantConditionMeans.(variableName)(idxAnalysis);

        DescriptivesAnalysis = appendConditionSummary( ...
            DescriptivesAnalysis, ...
            condition, ...
            metricLabel, ...
            analysisValues, ...
            analysisNote);
    end
end

%% ========================================================================
% 10. EXCLUSION LOG
% =========================================================================
% Raw data are never deleted. This log provides a transparent account of
% each analysis-specific exclusion [1,5].

ExclusionLog = buildExclusionLog( ...
    ParticipantConditionMeans, ...
    requiredTrialsPerParticipantCondition);

if ~preserveRawRecords
    error(['preserveRawRecords must remain true for this traceable ' ...
        'analysis workflow.']);
end

%% ========================================================================
% 11. WAVEFORM COMPLETENESS
% =========================================================================
WaveformCompleteness = table();

jointCodes = ["FE2";"FE3";"FE4"];
jointNames = ["Ankle";"Knee";"Hip"];

for c = 1:numel(conditionCodes)

    K = V{c}.Normatives.Kinematics;

    for j = 1:numel(jointCodes)

        data = double(K.(jointCodes(j)).data);

        nMissing = sum(~isfinite(data),'all');

        if nMissing == 0
            status = "Complete";
        else
            status = "Missing/non-finite waveform values";
        end

        temp = table( ...
            conditionLabels(c), ...
            jointNames(j), ...
            size(data,2), ...
            size(data,1), ...
            nMissing, ...
            status, ...
            'VariableNames',{ ...
                'Condition', ...
                'Joint', ...
                'AvailableCurves', ...
                'PointsPerCurve', ...
                'MissingOrNonFiniteValues', ...
                'Status'});

        WaveformCompleteness = ...
            [WaveformCompleteness; temp]; %#ok<AGROW>
    end
end

%% ========================================================================
% 12. PARTICIPANT FLOW
% =========================================================================
ParticipantFlow = table( ...
    [ ...
        "Recruited participants"
        "People in source walking-speed roster"
        "Complete waveform-model participants"
        "Expected waveform-model trials"
        "Available waveform-model trials"
        "Missing waveform-model trials"
        "Measured-speed source cells missing"
        "Target-speed fallbacks expected"], ...
    [ ...
        nRecruitedReported
        nSpeedRoster
        nModelParticipants
        nExpectedTrials
        nAvailableTrials
        nMissingTrials
        nMeasuredSpeedSubstitutions
        nMeasuredSpeedSubstitutions], ...
    [ ...
        "Previously reported; verify against recruitment records"
        "Computed from source WalkingSpeeds IDs"
        "Computed from common participant set across Norm_V1/V2/V3"
        "Participants × conditions × required trials"
        "Computed from clean MAT files"
        "Expected minus available"
        "Computed directly from source measured-speed cells"
        "Cleaner uses target speed when source measured speed is missing"], ...
    'VariableNames',{'PopulationStage','N','Evidence'});

%% ========================================================================
% 13. ANALYSIS DECISIONS AND REFERENCES
% =========================================================================
AnalysisDecisions = buildAnalysisDecisions( ...
    requiredTrialsPerParticipantCondition);

MethodologicalReferences = buildReferenceTable();

%% ========================================================================
% 14. DISTRIBUTION DIAGNOSTICS
% =========================================================================
DistributionDiagnostics = table();

if generateDistributionFigures

    DistributionDiagnostics = ...
        generateDistributionDiagnostics( ...
            DemographicsRaw, ...
            ParticipantConditionMeans, ...
            requiredTrialsPerParticipantCondition, ...
            figureDir);
end

%% ========================================================================
% 15. INPUT MANIFEST
% =========================================================================
InputManifest = buildInputManifest(requiredFiles);

%% ========================================================================
% 16. EXPORT WORKBOOK AND CSV FILES
% =========================================================================
writetable(ParticipantFlow,outputWorkbook, ...
    'Sheet','Participant Flow');

writetable(DemographicSummary,outputWorkbook, ...
    'Sheet','Demographic Summary');

writetable(SexSummary,outputWorkbook, ...
    'Sheet','Sex Summary');

writetable(DemographicsRaw,outputWorkbook, ...
    'Sheet','Demographics Raw');

writetable(SpeedSourceAudit,outputWorkbook, ...
    'Sheet','Speed Source Audit');

writetable(SourceConsistencyAudit,outputWorkbook, ...
    'Sheet','Source Consistency');

writetable(TrialData,outputWorkbook, ...
    'Sheet','Trial Data');

writetable(MissingnessSummary,outputWorkbook, ...
    'Sheet','Missingness');

writetable(ParticipantConditionMeans,outputWorkbook, ...
    'Sheet','Participant Means');

writetable(DescriptivesRaw,outputWorkbook, ...
    'Sheet','Descriptives Raw');

writetable(DescriptivesAnalysis,outputWorkbook, ...
    'Sheet','Descriptives Analysis');

writetable(ExclusionLog,outputWorkbook, ...
    'Sheet','Exclusion Log');

writetable(WaveformCompleteness,outputWorkbook, ...
    'Sheet','Waveform Completeness');

writetable(DistributionDiagnostics,outputWorkbook, ...
    'Sheet','Distribution Diagnostics');

writetable(AnalysisDecisions,outputWorkbook, ...
    'Sheet','Analysis Decisions');

writetable(MethodologicalReferences,outputWorkbook, ...
    'Sheet','References');

writetable(InputManifest,outputWorkbook, ...
    'Sheet','Input Manifest');

% CSV exports
tableExports = {
    ParticipantFlow, 'Participant_Flow.csv'
    DemographicSummary, 'Demographic_Summary.csv'
    SexSummary, 'Sex_Summary.csv'
    DemographicsRaw, 'Demographics_Raw.csv'
    SpeedSourceAudit, 'Speed_Source_Audit.csv'
    SourceConsistencyAudit, 'Source_Consistency_Audit.csv'
    TrialData, 'Trial_Data.csv'
    MissingnessSummary, 'Missingness_Summary.csv'
    ParticipantConditionMeans, 'Participant_Condition_Means.csv'
    DescriptivesRaw, 'Descriptives_Raw.csv'
    DescriptivesAnalysis, 'Descriptives_Analysis.csv'
    ExclusionLog, 'Exclusion_Log.csv'
    WaveformCompleteness, 'Waveform_Completeness.csv'
    DistributionDiagnostics, 'Distribution_Diagnostics.csv'
    AnalysisDecisions, 'Analysis_Decisions.csv'
    MethodologicalReferences, 'Methodological_References.csv'
    InputManifest, 'Input_Manifest.csv'
    };

for i = 1:size(tableExports,1)
    writetable( ...
        tableExports{i,1}, ...
        fullfile(outputDir,tableExports{i,2}));
end

%% ========================================================================
% 17. CONSOLE SUMMARY
% =========================================================================
fprintf('\n============================================================\n');
fprintf('ANALYSIS COMPLETE\n');
fprintf('============================================================\n');
fprintf('Model participants: %d\n',nModelParticipants);
fprintf('Available trials:   %d of %d\n', ...
    nAvailableTrials,nExpectedTrials);
fprintf('Female: %d (%.1f%%)\n', ...
    nFemale,100*nFemale/numel(sexCode));
fprintf('Male:   %d (%.1f%%)\n', ...
    nMale,100*nMale/numel(sexCode));
fprintf('Measured-speed target fallbacks: %d\n', ...
    nMeasuredSpeedSubstitutions);

flagged = SourceConsistencyAudit( ...
    SourceConsistencyAudit.ThreeTrialVectorExactDuplicate,:);

fprintf('\nConfirmed cross-variable source duplications:\n');
disp(flagged);

fprintf('\nAnalysis-specific exclusions:\n');
disp(ExclusionLog);

fprintf('\nMain workbook:\n  %s\n',outputWorkbook);
fprintf('Finished: %s\n',datestr(now));
fprintf('============================================================\n');

end

%% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function values = getPopulationVector(Population,candidateFields)
fieldName = firstExistingField(Population,candidateFields);
values = double(Population.(fieldName));
end

function values = getPopulationStringVector(Population,candidateFields)
fieldName = firstExistingField(Population,candidateFields);
values = string(Population.(fieldName));
end

function values = getStatData(Population,candidateFields)
fieldName = firstExistingField(Population,candidateFields);
S = Population.(fieldName);

if isstruct(S) && isfield(S,'data')
    values = double(S.data);
else
    values = double(S);
end
end

function tf = hasAnyField(S,candidateFields)
tf = false;

for i = 1:numel(candidateFields)
    if isfield(S,candidateFields{i})
        tf = true;
        return;
    end
end
end

function fieldName = firstExistingField(S,candidateFields)
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

function T = buildSpeedSourceAudit( ...
    sourceWorkbook,participantID,participantName, ...
    conditionCodes,conditionLabels)

speeds = readcell(sourceWorkbook, ...
    'Sheet','WalkingSpeeds', ...
    'UseExcel',false);

allRosterIDs = numericIDsFromColumn(speeds(:,2));

targetColumns = {
    [3 4 5]
    [6 7 8]
    [9 10 11]
    };

measuredColumns = {
    [13 14 15]
    [17 18 19]
    [21 22 23]
    };

T = table();

for p = 1:numel(participantID)

    row = findNumericID(speeds(:,2),participantID(p));

    if isempty(row)
        error('Participant %d is absent from WalkingSpeeds.', ...
            participantID(p));
    end

    for c = 1:numel(conditionCodes)

        for t = 1:3

            targetValue = ...
                cellScalarToDouble( ...
                    speeds{row,targetColumns{c}(t)});

            measuredRaw = ...
                cellScalarToDouble( ...
                    speeds{row,measuredColumns{c}(t)});

            measuredMissing = ~isfinite(measuredRaw);

            if measuredMissing
                expectedUsedValue = targetValue;
            else
                expectedUsedValue = measuredRaw;
            end

            trialID = string(sprintf( ...
                'P%02d_%s_T%d', ...
                participantID(p), ...
                conditionCodes(c), ...
                t));

            temp = table( ...
                trialID, ...
                participantID(p), ...
                participantName(p), ...
                conditionCodes(c), ...
                conditionLabels(c), ...
                t, ...
                targetValue, ...
                measuredRaw, ...
                measuredMissing, ...
                measuredMissing, ...
                expectedUsedValue, ...
                string(columnNumberToName( ...
                    targetColumns{c}(t)) + string(row)), ...
                string(columnNumberToName( ...
                    measuredColumns{c}(t)) + string(row)), ...
                'VariableNames',{ ...
                    'TrialID', ...
                    'ParticipantID', ...
                    'ParticipantName', ...
                    'ConditionCode', ...
                    'Condition', ...
                    'TrialNumber', ...
                    'TargetSpeed_kmh', ...
                    'MeasuredSpeedRaw_kmh', ...
                    'MeasuredSpeedMissingInSource', ...
                    'TargetFallbackExpected', ...
                    'ExpectedSpeedUsedByCleaner_kmh', ...
                    'TargetSpeedSourceCell', ...
                    'MeasuredSpeedSourceCell'});

            T = [T; temp]; %#ok<AGROW>
        end
    end
end

% This repeated column is included only so the source-roster N can be
% computed and carried with the audit without relying on a hidden variable.
T.AllSourceRosterParticipantID = ...
    nan(height(T),1);

nCopy = min(numel(allRosterIDs),height(T));

T.AllSourceRosterParticipantID(1:nCopy) = ...
    allRosterIDs(1:nCopy);
end

function T = buildSourceConsistencyAudit( ...
    sourceWorkbook,participantID,participantName, ...
    conditionCodes,conditionLabels)

spatio = readcell(sourceWorkbook, ...
    'Sheet','Spatiotemporal', ...
    'UseExcel',false);

speeds = readcell(sourceWorkbook, ...
    'Sheet','WalkingSpeeds', ...
    'UseExcel',false);

strideColumns = {
    [3 4 5]
    [7 8 9]
    [11 12 13]
    };

measuredColumns = {
    [13 14 15]
    [17 18 19]
    [21 22 23]
    };

T = table();

for p = 1:numel(participantID)

    spatioRow = findNumericID(spatio(:,2),participantID(p));
    speedRow = findNumericID(speeds(:,2),participantID(p));

    if isempty(spatioRow)
        error('Participant %d is absent from Spatiotemporal.', ...
            participantID(p));
    end

    if isempty(speedRow)
        error('Participant %d is absent from WalkingSpeeds.', ...
            participantID(p));
    end

    for c = 1:numel(conditionCodes)

        strideValues = cellVectorToDouble( ...
            spatio(spatioRow,strideColumns{c}));

        measuredValues = cellVectorToDouble( ...
            speeds(speedRow,measuredColumns{c}));

        completeVectors = ...
            all(isfinite(strideValues)) && ...
            all(isfinite(measuredValues));

        exactDuplicate = ...
            completeVectors && ...
            all(abs(strideValues - measuredValues) < 1e-12);

        strideCells = makeCellRangeString( ...
            strideColumns{c},spatioRow);

        measuredCells = makeCellRangeString( ...
            measuredColumns{c},speedRow);

        if exactDuplicate
            interpretation = ...
                "Confirmed source cross-variable duplication; affected stride-derived outcomes require exclusion pending source correction";
        elseif ~completeVectors
            interpretation = ...
                "One or both source vectors contain missing/non-numeric values";
        else
            interpretation = ...
                "No complete three-trial vector duplication detected";
        end

        temp = table( ...
            participantID(p), ...
            participantName(p), ...
            conditionCodes(c), ...
            conditionLabels(c), ...
            string(mat2str(strideValues',6)), ...
            string(mat2str(measuredValues',6)), ...
            completeVectors, ...
            exactDuplicate, ...
            strideCells, ...
            measuredCells, ...
            interpretation, ...
            'VariableNames',{ ...
                'ParticipantID', ...
                'ParticipantName', ...
                'ConditionCode', ...
                'Condition', ...
                'StrideLengthVector_m', ...
                'MeasuredSpeedVector_kmh', ...
                'BothVectorsComplete', ...
                'ThreeTrialVectorExactDuplicate', ...
                'StrideSourceCells', ...
                'MeasuredSpeedSourceCells', ...
                'Interpretation'});

        T = [T; temp]; %#ok<AGROW>
    end
end
end

function T = buildMissingnessSummary(TrialData)

variables = [ ...
    "MeasuredSpeedUsed_m_s"
    "DimensionlessSpeed_v_over_sqrt_gL"
    "FroudeNumber_v2_over_gL"
    "StrideLength_m"
    "StepLength_m"
    "Cadence_steps_min"
    "StancePhase_percent"
    "SwingPhase_percent"];

conditions = unique(TrialData.Condition,'stable');

T = table();

for c = 1:numel(conditions)

    idxCondition = TrialData.Condition == conditions(c);

    for v = 1:numel(variables)

        values = TrialData.(variables(v))(idxCondition);
        nExpected = numel(values);
        nAvailable = sum(isfinite(values));
        nMissing = nExpected - nAvailable;

        temp = table( ...
            conditions(c), ...
            variables(v), ...
            nExpected, ...
            nAvailable, ...
            nMissing, ...
            100*nMissing/max(nExpected,1), ...
            'VariableNames',{ ...
                'Condition', ...
                'Variable', ...
                'NExpectedTrials', ...
                'NAvailableTrials', ...
                'NMissingTrials', ...
                'PercentMissing'});

        T = [T; temp]; %#ok<AGROW>
    end
end
end

function T = appendContinuousSummary( ...
    T,characteristic,values,note)

S = summarizeVector(values);

temp = table( ...
    string(characteristic), ...
    S.N, ...
    S.Mean, ...
    S.SD, ...
    S.Median, ...
    S.Q1, ...
    S.Q3, ...
    S.Minimum, ...
    S.Maximum, ...
    S.AdjustedSkewness, ...
    string(formatMeanSD(S.Mean,S.SD)), ...
    string(formatMedianIQR(S.Median,S.Q1,S.Q3)), ...
    string(note), ...
    'VariableNames',{ ...
        'Characteristic', ...
        'N', ...
        'Mean', ...
        'SD', ...
        'Median', ...
        'Q1', ...
        'Q3', ...
        'Minimum', ...
        'Maximum', ...
        'AdjustedSkewness', ...
        'MeanSD_Text', ...
        'MedianIQR_Text', ...
        'ReportingNote'});

T = [T; temp];
end

function T = appendConditionSummary( ...
    T,condition,metric,values,note)

S = summarizeVector(values);

temp = table( ...
    string(condition), ...
    string(metric), ...
    S.N, ...
    S.Mean, ...
    S.SD, ...
    S.Median, ...
    S.Q1, ...
    S.Q3, ...
    S.Minimum, ...
    S.Maximum, ...
    S.AdjustedSkewness, ...
    string(formatMeanSD(S.Mean,S.SD)), ...
    string(formatMedianIQR(S.Median,S.Q1,S.Q3)), ...
    string(note), ...
    'VariableNames',{ ...
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
        'AdjustedSkewness', ...
        'MeanSD_Text', ...
        'MedianIQR_Text', ...
        'AnalysisNote'});

T = [T; temp];
end

function S = summarizeVector(values)

values = double(values(:));
values = values(isfinite(values));

S = struct();
S.N = numel(values);

if isempty(values)
    S.Mean = NaN;
    S.SD = NaN;
    S.Median = NaN;
    S.Q1 = NaN;
    S.Q3 = NaN;
    S.Minimum = NaN;
    S.Maximum = NaN;
    S.AdjustedSkewness = NaN;
    return;
end

S.Mean = mean(values);
S.SD = std(values,0);
S.Median = median(values);
S.Q1 = percentileLinear(values,25);
S.Q3 = percentileLinear(values,75);
S.Minimum = min(values);
S.Maximum = max(values);
S.AdjustedSkewness = adjustedSampleSkewness(values);
end

function value = percentileLinear(values,percent)

values = sort(double(values(:)));
n = numel(values);

if n == 0
    value = NaN;
    return;
end

if n == 1
    value = values(1);
    return;
end

position = 1 + (n-1)*(percent/100);
lowerIndex = floor(position);
upperIndex = ceil(position);

if lowerIndex == upperIndex
    value = values(lowerIndex);
else
    weight = position - lowerIndex;
    value = ...
        values(lowerIndex)*(1-weight) + ...
        values(upperIndex)*weight;
end
end

function value = adjustedSampleSkewness(values)

values = double(values(:));
values = values(isfinite(values));
n = numel(values);

if n < 3
    value = NaN;
    return;
end

s = std(values,0);

if s <= eps
    value = 0;
    return;
end

z = (values - mean(values)) ./ s;

value = n / ((n-1)*(n-2)) * sum(z.^3);
end

function textValue = formatMeanSD(meanValue,sdValue)

if ~isfinite(meanValue) || ~isfinite(sdValue)
    textValue = "";
else
    textValue = sprintf('%.3f +/- %.3f',meanValue,sdValue);
end
end

function textValue = formatMedianIQR(medianValue,q1,q3)

if ~all(isfinite([medianValue q1 q3]))
    textValue = "";
else
    textValue = sprintf('%.3f [%.3f, %.3f]', ...
        medianValue,q1,q3);
end
end

function T = buildExclusionLog( ...
    ParticipantConditionMeans,requiredTrials)

T = table();

metricVariables = [ ...
    "WalkingSpeed_m_s"
    "DimensionlessSpeed_v_over_sqrt_gL"
    "FroudeNumber_v2_over_gL"
    "StrideLength_m"
    "StepLength_m"
    "Cadence_steps_min"
    "StancePhase_percent"
    "SwingPhase_percent"];

metricLabels = [ ...
    "Walking speed"
    "Dimensionless speed"
    "Froude number"
    "Stride length"
    "Step length"
    "Cadence"
    "Stance phase"
    "Swing phase"];

metricCountVariables = [ ...
    "NWalkingSpeedTrials"
    "NDimensionlessSpeedTrials"
    "NFroudeNumberTrials"
    "NStrideTrials"
    "NStepTrials"
    "NCadenceTrials"
    "NStanceTrials"
    "NSwingTrials"];

for i = 1:height(ParticipantConditionMeans)

    row = ParticipantConditionMeans(i,:);

    for m = 1:numel(metricVariables)

        nAvailable = row.(metricCountVariables(m));

        if nAvailable < requiredTrials

            temp = exclusionRows( ...
                row, ...
                metricLabels(m), ...
                sprintf('%d of %d required trial values available', ...
                    nAvailable,requiredTrials), ...
                "Excluded from the main summary for this metric only; raw values and unaffected metrics retained");

            T = [T; temp]; %#ok<AGROW>
        end
    end

    if row.SourceVectorDuplicate

        affectedMetrics = [ ...
            "Stride length"
            "Step length"
            "Cadence"];

        for m = 1:numel(affectedMetrics)

            temp = exclusionRows( ...
                row, ...
                affectedMetrics(m), ...
                "Source workbook contains identical three-trial vectors for stride length (m) and measured speed (km/h)", ...
                "Excluded from the affected descriptive outcome only; speed, phase and waveform data retained");

            T = [T; temp]; %#ok<AGROW>
        end
    end
end

if isempty(T)
    T = table( ...
        nan(0,1), ...
        strings(0,1), ...
        strings(0,1), ...
        strings(0,1), ...
        strings(0,1), ...
        strings(0,1), ...
        strings(0,1), ...
        'VariableNames',{ ...
            'ParticipantID', ...
            'ParticipantName', ...
            'ConditionCode', ...
            'Condition', ...
            'AffectedMetric', ...
            'Reason', ...
            'Action'});
end
end

function T = exclusionRows(row,metric,reason,action)

T = table( ...
    row.ParticipantID, ...
    row.ParticipantName, ...
    row.ConditionCode, ...
    row.Condition, ...
    string(metric), ...
    string(reason), ...
    string(action), ...
    'VariableNames',{ ...
        'ParticipantID', ...
        'ParticipantName', ...
        'ConditionCode', ...
        'Condition', ...
        'AffectedMetric', ...
        'Reason', ...
        'Action'});
end

function T = buildAnalysisDecisions(requiredTrials)

T = table( ...
    [ ...
        "Article scope"
        "Independent statistical unit"
        "Repeated trials"
        "Continuous summaries"
        "Distribution assessment"
        "Hypothesis testing"
        "Missing data"
        "Outlier handling"
        "Source inconsistency"
        "Affected-variable handling"
        "Dimensionless speed"
        "Froude number"
        "Waveform model context"], ...
    [ ...
        "Descriptive dataset overview and technical validation"
        "Participant"
        sprintf('%d trials averaged within participant and condition',requiredTrials)
        "Both mean/SD and median/IQR exported"
        "Histograms, Q-Q plots and skewness used as supporting diagnostics"
        "Not performed by this script"
        "Counts and denominators reported; no imputation"
        "No physiological cut-off automatically excludes a record"
        "Complete three-trial cross-variable vector duplication is flagged from the source workbook"
        "Only directly affected stride-derived summaries are excluded; raw and unaffected data retained"
        "v/sqrt(gL)"
        "v^2/(gL)"
        "Speed, age, sex and BMI model context follows Chehab and Moissenet"], ...
    [ ...
        "[1]"
        "[3]"
        "[3]"
        "[2]"
        "[4]"
        "[1]"
        "[2,5]"
        "Internal pre-specified decision"
        "Internal provenance check"
        "[5] and transparent outcome-specific handling"
        "[6]"
        "[6]"
        "[7,8]"], ...
    'VariableNames',{ ...
        'AnalysisComponent', ...
        'Decision', ...
        'ReferenceSupport'});
end

function T = buildReferenceTable()

T = table( ...
    (1:8)', ...
    [ ...
        "Scientific Data submission guidelines"
        "SAMPL statistical-reporting guidelines"
        "Pseudoreplication and independent experimental units"
        "Normality assessment and graphical diagnostics"
        "TARMOS missing-data framework"
        "Dynamic similarity and Froude scaling"
        "Speed, age, sex and BMI as gait-profile covariates"
        "Moissenet gait-pattern regression and LOSO validation"], ...
    [ ...
        "Scientific Data. Submission Guidelines."
        "Lang TA, Altman DG. Basic statistical reporting for articles published in biomedical journals: the SAMPL Guidelines. Int J Nurs Stud. 2015;52(1):5-9."
        "Lazic SE. The problem of pseudoreplication in neuroscientific studies: is it affecting your analysis? BMC Neurosci. 2010;11:5."
        "Ghasemi A, Zahediasl S. Normality tests for statistical analysis: a guide for non-statisticians. Int J Endocrinol Metab. 2012;10(2):486-489."
        "Lee KJ, et al. Framework for the treatment and reporting of missing data in observational studies: the TARMOS framework. J Clin Epidemiol. 2021;134:79-88."
        "Alexander RM, Jayes AS. A dynamic similarity hypothesis for the gaits of quadrupedal mammals. J Zool. 1983;201:135-152."
        "Chehab EF, Andriacchi TP, Favre J. Speed, age, sex, and body mass index provide a rigorous basis for comparing lower-extremity gait profiles. J Biomech. 2017;58:11-20."
        "Moissenet F, Leboeuf F, Armand S. Lower limb sagittal gait kinematics can be predicted based on walking speed, gender, age and BMI. Sci Rep. 2019;9:9510."], ...
    [ ...
        "https://www.nature.com/sdata/publish/submission-guidelines"
        "https://doi.org/10.1016/j.ijnurstu.2014.09.006"
        "https://doi.org/10.1186/1471-2202-11-5"
        "https://doi.org/10.5812/ijem.3505"
        "https://doi.org/10.1016/j.jclinepi.2021.01.008"
        "https://doi.org/10.1111/j.1469-7998.1983.tb04266.x"
        "https://doi.org/10.1016/j.jbiomech.2017.04.014"
        "https://doi.org/10.1038/s41598-019-45397-4"], ...
    'VariableNames',{ ...
        'ReferenceNumber', ...
        'MethodologicalUse', ...
        'Citation', ...
        'URL'});
end

function T = generateDistributionDiagnostics( ...
    DemographicsRaw,ParticipantConditionMeans,requiredTrials,figureDir)

T = table();

demographicVariables = [ ...
    "Age_years"
    "Height_m"
    "BodyMass_kg"
    "BMI_kg_m2"
    "LowerLimbLength_m"];

demographicLabels = [ ...
    "Age (years)"
    "Height (m)"
    "Body mass (kg)"
    "BMI (kg/m^2)"
    "Lower-limb length (m)"];

for i = 1:numel(demographicVariables)

    values = DemographicsRaw.(demographicVariables(i));
    fileBase = "Demographic_" + demographicVariables(i);

    figurePath = makeDiagnosticFigure( ...
        values, ...
        demographicLabels(i), ...
        fullfile(figureDir,fileBase + ".png"));

    S = summarizeVector(values);

    temp = table( ...
        "Demographic", ...
        "All", ...
        demographicLabels(i), ...
        S.N, ...
        S.AdjustedSkewness, ...
        string(figurePath), ...
        'VariableNames',{ ...
            'DatasetLevel', ...
            'Condition', ...
            'Variable', ...
            'N', ...
            'AdjustedSkewness', ...
            'FigurePath'});

    T = [T; temp]; %#ok<AGROW>
end

metricVariables = [ ...
    "WalkingSpeed_m_s"
    "DimensionlessSpeed_v_over_sqrt_gL"
    "FroudeNumber_v2_over_gL"
    "StrideLength_m"
    "StepLength_m"
    "Cadence_steps_min"
    "StancePhase_percent"
    "SwingPhase_percent"];

metricLabels = [ ...
    "Walking speed (m/s)"
    "Dimensionless speed v/sqrt(gL)"
    "Froude number v^2/(gL)"
    "Stride length (m)"
    "Step length (m)"
    "Cadence (steps/min)"
    "Stance phase (%)"
    "Swing phase (%)"];

metricCountVariables = [ ...
    "NWalkingSpeedTrials"
    "NDimensionlessSpeedTrials"
    "NFroudeNumberTrials"
    "NStrideTrials"
    "NStepTrials"
    "NCadenceTrials"
    "NStanceTrials"
    "NSwingTrials"];

conditions = unique(ParticipantConditionMeans.Condition,'stable');

for c = 1:numel(conditions)

    for m = 1:numel(metricVariables)

        idx = ParticipantConditionMeans.Condition == conditions(c) & ...
            ParticipantConditionMeans.TrialsPresent == requiredTrials & ...
            ParticipantConditionMeans.(metricCountVariables(m)) == ...
                requiredTrials;

        if any(metricVariables(m) == [ ...
                "StrideLength_m", ...
                "StepLength_m", ...
                "Cadence_steps_min"])

            idx = idx & ...
                ~ParticipantConditionMeans.SourceVectorDuplicate;
        end

        values = ParticipantConditionMeans.(metricVariables(m))(idx);

        fileBase = ...
            "ParticipantMean_" + conditions(c) + "_" + ...
            metricVariables(m);

        figurePath = makeDiagnosticFigure( ...
            values, ...
            conditions(c) + ": " + metricLabels(m), ...
            fullfile(figureDir,fileBase + ".png"));

        S = summarizeVector(values);

        temp = table( ...
            "Participant-condition mean", ...
            conditions(c), ...
            metricLabels(m), ...
            S.N, ...
            S.AdjustedSkewness, ...
            string(figurePath), ...
            'VariableNames',{ ...
                'DatasetLevel', ...
                'Condition', ...
                'Variable', ...
                'N', ...
                'AdjustedSkewness', ...
                'FigurePath'});

        T = [T; temp]; %#ok<AGROW>
    end
end
end

function figurePath = makeDiagnosticFigure(values,titleText,figurePath)

values = double(values(:));
values = values(isfinite(values));

if isempty(values)
    figurePath = "";
    return;
end

fig = figure( ...
    'Visible','off', ...
    'Position',[100 100 900 360]);

tiledlayout(fig,1,2, ...
    'Padding','compact', ...
    'TileSpacing','compact');

nexttile;
histogram(values);
xlabel('Value');
ylabel('Frequency');
title('Histogram');
grid on;
box on;

nexttile;

if exist('qqplot','file') == 2
    qqplot(values);
    title('Normal Q-Q plot');
else
    sortedValues = sort(values);
    plottingPositions = ...
        ((1:numel(sortedValues))' - 0.5) ./ numel(sortedValues);

    theoreticalQuantiles = ...
        sqrt(2) .* erfinv(2*plottingPositions - 1);

    plot(theoreticalQuantiles,sortedValues,'o');
    xlabel('Theoretical normal quantiles');
    ylabel('Observed quantiles');
    title('Normal Q-Q plot');
    grid on;
    box on;
end

sgtitle(titleText,'Interpreter','none');

exportgraphics(fig,figurePath,'Resolution',200);
close(fig);
end

function T = buildInputManifest(requiredFiles)

T = table();

for i = 1:numel(requiredFiles)

    info = dir(requiredFiles{i});

    temp = table( ...
        string(requiredFiles{i}), ...
        string(info.name), ...
        info.bytes, ...
        string(info.date), ...
        'VariableNames',{ ...
            'FullPath', ...
            'FileName', ...
            'Bytes', ...
            'ModifiedDate'});

    T = [T; temp]; %#ok<AGROW>
end
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

function value = cellScalarToDouble(cellValue)

if isnumeric(cellValue) && isscalar(cellValue)
    value = double(cellValue);
else
    value = NaN;
end
end

function values = cellVectorToDouble(cells)

values = nan(numel(cells),1);

for i = 1:numel(cells)
    values(i) = cellScalarToDouble(cells{i});
end
end

function tf = finiteEqual(a,b,tolerance)

tf = isfinite(a) && isfinite(b) && abs(a-b) <= tolerance;
end

function textValue = makeCellRangeString(columns,row)

textValue = ...
    columnNumberToName(columns(1)) + string(row) + ":" + ...
    columnNumberToName(columns(end)) + string(row);
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
