% =========================================================================
% FIT NORMAL GAIT: Predict kinematics based on walking speed, age, sex, BMI
% =========================================================================
% Function: extractData
% =========================================================================
% Original author: F. Moissenet
% Original creation: 06 July 2017
%
% Corrected version:
%   1. Extracts cycle indices independently for each speed condition.
%   2. Creates one predictor entry for every extracted waveform.
%   3. Prevents cumulative construction of IFS1 and IFS2.
%   4. Maintains alignment among waveform, gait and predictor variables.
%   5. Converts cadence from steps/min to steps/s before normalization.
%   6. Calculates dimensionless/Froude walking speed using individual
%      estimated lower-limb length.
%   7. Checks all output dimensions before returning.
% =========================================================================

function Raw = extractData( ...
    File, Joint, icycle, isubject, subject_sub, rsubject, ...
    N, V, T, J, type)

% =========================================================================
% Input checks
% =========================================================================
if nargin ~= 11
    error(['extractData requires eleven inputs: File, Joint, icycle, ', ...
        'isubject, subject_sub, rsubject, N, V, T, J and type.']);
end

type = lower(char(type));

if ~ismember(type, {'training', 'testing'})
    error('type must be either ''training'' or ''testing''.');
end

if J < 1 || J > numel(Joint)
    error('J is outside the valid range of the Joint structure.');
end

if V < 1 || V > numel(File)
    error('V is outside the valid range of the File structure.');
end

% =========================================================================
% Initialisation
% =========================================================================
Raw = struct();

Raw.kinematics   = [];
Raw.walkingSpeed = [];
Raw.stepLength   = [];
Raw.cadence      = [];
Raw.IFS1         = [];
Raw.IFS2         = [];
Raw.IFO          = [];
Raw.CFS          = [];
Raw.CFO          = [];
Raw.age          = [];
Raw.sex          = [];
Raw.BMI          = [];
Raw.LL           = [];

froudeVelocity = [];

% =========================================================================
% Merge observations across walking-speed conditions
% =========================================================================
for v = 1:V

    % ---------------------------------------------------------------------
    % Determine the waveform columns required for this condition
    % ---------------------------------------------------------------------
    if strcmp(type, 'training')

        selectedSubjects = subject_sub(:)';

        selectedSubjects = selectedSubjects( ...
            isfinite(selectedSubjects) & ...
            selectedSubjects >= 1 & ...
            selectedSubjects <= N & ...
            selectedSubjects ~= rsubject);

        if isempty(selectedSubjects)
            cycleIndex = [];
        else
            cycleMatrix = icycle(selectedSubjects, :, v);

            % Transpose before reshaping so that all cycles belonging to one
            % participant remain together, matching the original ordering.
            cycleIndex = reshape(cycleMatrix', 1, []);
            cycleIndex = cycleIndex(isfinite(cycleIndex));
        end

    else
        % Testing set contains only the withheld participant.
        if ~isscalar(rsubject) || ...
                ~isfinite(rsubject) || ...
                rsubject < 1 || ...
                rsubject > N

            error(['For testing extraction, rsubject must be a valid ', ...
                'participant index between 1 and N.']);
        end

        cycleMatrix = icycle(rsubject, :, v);
        cycleIndex = reshape(cycleMatrix', 1, []);
        cycleIndex = cycleIndex(isfinite(cycleIndex));
    end

    cycleIndex = round(cycleIndex);

    if isempty(cycleIndex)
        continue;
    end

    % ---------------------------------------------------------------------
    % Validate the selected waveform columns
    % ---------------------------------------------------------------------
    jointCode = Joint(J).code;

    if ~isfield(File(v).Normatives.Kinematics, jointCode)
        error(['Condition %d does not contain the required kinematic ', ...
            'field Normatives.Kinematics.%s.'], v, jointCode);
    end

    nAvailableCycles = size( ...
        File(v).Normatives.Kinematics.(jointCode).data, 2);

    if any(cycleIndex < 1 | cycleIndex > nAvailableCycles)
        error(['Condition %d contains a requested cycle index outside ', ...
            'the available range 1:%d.'], ...
            v, nAvailableCycles);
    end

    % Participant index belonging to every selected waveform column.
    participantIndex = isubject(cycleIndex, v);
    participantIndex = reshape(participantIndex, 1, []);

    if any(~isfinite(participantIndex))
        error(['Condition %d contains selected waveform columns without ', ...
            'a corresponding participant index in isubject.'], v);
    end

    participantIndex = round(participantIndex);

    nPopulation = numel(File(v).Population.L0.data);

    if any(participantIndex < 1 | participantIndex > nPopulation)
        error(['Condition %d contains participant indices outside the ', ...
            'available Population range 1:%d.'], ...
            v, nPopulation);
    end

    nCurrent = numel(cycleIndex);

    % ---------------------------------------------------------------------
    % Extract the current condition's kinematics and gait variables
    % ---------------------------------------------------------------------
    currentKinematics = ...
        File(v).Normatives.Kinematics.(jointCode).data(:, cycleIndex) ...
        .* Joint(J).sign;

    currentWalkingSpeed = reshape( ...
        File(v).Normatives.Gaitparameters.mean_velocity.data(cycleIndex), ...
        1, []);

    currentStepLength = reshape( ...
        File(v).Normatives.Gaitparameters.step_length.data(cycleIndex), ...
        1, []);

    currentCadence = reshape( ...
        File(v).Normatives.Gaitparameters.cadence.data(cycleIndex), ...
        1, []);

    currentIFO = reshape( ...
        File(v).Normatives.Phases.p5.data(cycleIndex), ...
        1, []);

    currentCFS = reshape( ...
        File(v).Normatives.Phases.p4.data(cycleIndex), ...
        1, []);

    currentCFO = reshape( ...
        File(v).Normatives.Phases.p2.data(cycleIndex), ...
        1, []);

    % ---------------------------------------------------------------------
    % Extract the predictor values for the same waveform columns
    % ---------------------------------------------------------------------
    currentLL = reshape( ...
        File(v).Population.L0.data(participantIndex), ...
        1, []);

    currentAge = reshape( ...
        File(v).Population.age.data(participantIndex), ...
        1, []);

    currentSex = reshape( ...
        File(v).Population.gender.data(participantIndex), ...
        1, []);

    currentHeight = reshape( ...
        File(v).Population.height.data(participantIndex), ...
        1, []);

    currentWeight = reshape( ...
        File(v).Population.weight.data(participantIndex), ...
        1, []);

    if any(~isfinite(currentLL) | currentLL <= 0)
        error(['Condition %d contains missing or non-positive ', ...
            'lower-limb-length values.'], v);
    end

    if any(~isfinite(currentHeight) | currentHeight <= 0)
        error(['Condition %d contains missing or non-positive ', ...
            'height values.'], v);
    end

    currentBMI = currentWeight ./ (currentHeight .^ 2);

    % Froude reference velocity: sqrt(gL)
    currentFroudeVelocity = sqrt(9.81 .* currentLL);

    % ---------------------------------------------------------------------
    % Append only this condition's observations
    % ---------------------------------------------------------------------
    Raw.kinematics = [Raw.kinematics currentKinematics];

    Raw.walkingSpeed = ...
        [Raw.walkingSpeed currentWalkingSpeed];

    Raw.stepLength = ...
        [Raw.stepLength currentStepLength];

    Raw.cadence = ...
        [Raw.cadence currentCadence];

    % One start and endpoint per current waveform—not cumulative counts.
    Raw.IFS1 = ...
        [Raw.IFS1 ones(1, nCurrent)];

    Raw.IFS2 = ...
        [Raw.IFS2 T .* ones(1, nCurrent)];

    Raw.IFO = ...
        [Raw.IFO currentIFO];

    Raw.CFS = ...
        [Raw.CFS currentCFS];

    Raw.CFO = ...
        [Raw.CFO currentCFO];

    Raw.age = ...
        [Raw.age currentAge];

    Raw.sex = ...
        [Raw.sex currentSex];

    Raw.BMI = ...
        [Raw.BMI currentBMI];

    Raw.LL = ...
        [Raw.LL currentLL];

    froudeVelocity = ...
        [froudeVelocity currentFroudeVelocity];

end

% =========================================================================
% Check raw alignment before dimensionless normalisation
% =========================================================================
nObservations = size(Raw.kinematics, 2);

fieldsToCheck = { ...
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

for f = 1:numel(fieldsToCheck)
    fieldName = fieldsToCheck{f};

    if numel(Raw.(fieldName)) ~= nObservations
        error(['Data-alignment failure: Raw.%s contains %d values, ', ...
            'but Raw.kinematics contains %d waveform columns.'], ...
            fieldName, numel(Raw.(fieldName)), nObservations);
    end
end

if numel(froudeVelocity) ~= nObservations
    error(['Data-alignment failure: the Froude-velocity vector contains ', ...
        '%d values, but Raw.kinematics contains %d waveform columns.'], ...
        numel(froudeVelocity), nObservations);
end

if nObservations == 0
    warning('extractData:noObservations', ...
        'No observations were extracted for the requested dataset.');
    return;
end

% =========================================================================
% Dimensionless normalisation
% =========================================================================

% mean_velocity must already be stored in metres per second.
Raw.walkingSpeed = Raw.walkingSpeed ./ froudeVelocity;

% Dimensionless step length.
Raw.stepLength = Raw.stepLength ./ Raw.LL;

% Source cadence is stored in steps per minute.
% Convert it to steps per second before dimensionless normalisation.
cadenceStepsPerSecond = Raw.cadence ./ 60;

Raw.cadence = cadenceStepsPerSecond ./ sqrt(9.81 ./ Raw.LL);

% =========================================================================
% Final finite-value checks for regression predictors
% =========================================================================
predictorMatrix = [ ...
    Raw.walkingSpeed(:), ...
    Raw.age(:), ...
    Raw.sex(:), ...
    Raw.BMI(:)];

if any(~isfinite(predictorMatrix(:)))
    error(['One or more regression predictors contain NaN or Inf after ', ...
        'data extraction and dimensionless normalisation.']);
end

end
%%
% % =========================================================================
% % =========================================================================
% % FIT NORMAL GAIT: Predict kinematics based on walking speed, age, sex, BMI
% % =========================================================================
% % Function: extractData
% % =========================================================================
% % Authors: F. Moissenet
% % Creation: 06 July 2017
% % Version: v1.0
% % =========================================================================
% % =========================================================================
% 
% function Raw = extractData(File,Joint,icycle,isubject,subject_sub,rsubject,N,V,T,J,type)
% 
% % =========================================================================
% % Initialisation
% % =========================================================================
% Raw.kinematics = [];
% Raw.walkingSpeed = [];
% Raw.stepLength = [];
% Raw.cadence = [];
% Raw.IFS1 = [];
% Raw.IFS2 = [];
% Raw.IFO = [];
% Raw.CFS = [];
% Raw.CFO = [];
% Raw.age = [];
% Raw.sex = [];
% Raw.BMI = [];
% Raw.LL = [];
% 
% % =========================================================================
% % Merge data related to each walking speed condition
% % =========================================================================
% walkingSpeed_froude = [];
% for v = 1:V
% 
%     % Store parameters
%     % ---------------------------------------------------------------------
%     if strcmp(type,'training')
%         temp = reshape(icycle(subject_sub,:,v)',1,...
%             size(icycle(subject_sub,:,v),1)*size(icycle(subject_sub,:,v),2));
%         temp2 = [temp(~isnan(temp)) nan(1,600-length(temp(~isnan(temp))))];
%         temp2 = temp2(~isnan(temp2));
%     elseif strcmp(type,'testing')
%         temp = reshape(icycle(rsubject,:,v)',1,size(icycle(rsubject,:,v),1)*size(icycle(rsubject,:,v),2));
%         temp2 = [temp(~isnan(temp)) nan(1,600-length(temp(~isnan(temp))))];
%         temp2 = temp2(~isnan(temp2));
%     end
%     Raw.kinematics = [Raw.kinematics ...
%         File(v).Normatives.Kinematics.(Joint(J).code).data(:,temp2)*(Joint(J).sign)];
%     Raw.walkingSpeed = [Raw.walkingSpeed ...
%         File(v).Normatives.Gaitparameters.mean_velocity.data(:,temp2)];
%     Raw.stepLength = [Raw.stepLength ...
%         File(v).Normatives.Gaitparameters.step_length.data(:,temp2)];
%     Raw.cadence = [Raw.cadence ...
%         File(v).Normatives.Gaitparameters.cadence.data(:,temp2)];
%     Raw.IFS1 = [Raw.IFS1 repmat(1,[1 size(Raw.walkingSpeed,2)])];
%     Raw.IFS2 = [Raw.IFS2 repmat(T,[1 size(Raw.walkingSpeed,2)])];
%     Raw.IFO = [Raw.IFO File(v).Normatives.Phases.p5.data(:,temp2)];
%     Raw.CFS = [Raw.CFS File(v).Normatives.Phases.p4.data(:,temp2)];
%     Raw.CFO = [Raw.CFO File(v).Normatives.Phases.p2.data(:,temp2)];
%     clear temp temp2;
% 
%     % Store predictors
%     % ---------------------------------------------------------------------
%     temp = [];
%     if strcmp(type,'training')
%         for i = 1:size(isubject(:,v),1)
%             if isubject(i,v) ~= rsubject && ...
%                     ~isnan(isubject(i,v)) && ...
%                     isubject(i,v) <= N
%                 temp = [temp isubject(i,v)];
%             end
%         end
%     elseif strcmp(type,'testing')
%         for i = 1:size(isubject(:,v),1)
%             if isubject(i,v) == rsubject && ...
%                     ~isnan(isubject(i,v)) && ...
%                     isubject(i,v) <= N
%                 temp = [temp isubject(i,v)];
%             end
%         end
%     end
%     for i = 1:length(temp)
%         temp1(1,i) = sqrt(File(v).Population.L0.data(temp(i))*9.81); % Froude velocity
%         temp2(1,i) = File(v).Population.age.data(temp(i));
%         temp3(1,i) = File(v).Population.gender.data(temp(i));
%         temp4(1,i) = File(v).Population.height.data(temp(i));
%         temp5(1,i) = File(v).Population.weight.data(temp(i));
%         temp6(1,i) = File(v).Population.L0.data(temp(i));
%     end
%     walkingSpeed_froude = [walkingSpeed_froude temp1];
%     Raw.age = [Raw.age temp2];
%     Raw.sex = [Raw.sex temp3];
%     Raw.BMI = [Raw.BMI temp5./temp4.^2];
%     Raw.LL = [Raw.LL temp6];
%     clear temp1 temp2 temp3 temp4 temp5 temp6 temp;
% 
% end
% 
% % =========================================================================
% % Express walking speed as a fraction of the Froude velocity
% % =========================================================================
% Raw.walkingSpeed = Raw.walkingSpeed./walkingSpeed_froude;
% Raw.stepLength = Raw.stepLength./Raw.LL;
% Raw.cadence = Raw.cadence./sqrt(9.81./Raw.LL);