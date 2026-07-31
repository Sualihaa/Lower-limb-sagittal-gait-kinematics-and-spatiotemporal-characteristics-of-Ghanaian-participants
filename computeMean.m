% =========================================================================
% FIT NORMAL GAIT: Predict kinematics based on walking speed, age, sex, BMI
% =========================================================================
% Function: computeMean
% =========================================================================
% Original author: F. Moissenet
% Original creation: 06 July 2017
%
% Corrected version:
%   1. Each Froude-speed bin is processed independently.
%   2. Corrected lower-limb-length assignment.
%   3. RMSE, R2, MAX and VAF arrays are reset for every speed bin.
%   4. Maximum error is calculated as max(abs(error)).
%   5. Zero-variance waveforms return NaN for R2/VAF.
%   6. Pointwise waveform SD and bin sample counts are stored.
% =========================================================================

function [Mean, Population] = computeMean(Sort, minVf, maxVf, stepVf)

% =========================================================================
% Input checks
% =========================================================================
if nargin ~= 4
    error(['computeMean requires four inputs: ', ...
        'Sort, minVf, maxVf and stepVf.']);
end

if stepVf <= 0
    error('stepVf must be greater than zero.');
end

if minVf > maxVf
    error('minVf must be less than or equal to maxVf.');
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
    if ~isfield(Sort, requiredFields{f})
        error('Sort is missing the required field: Sort.%s', ...
            requiredFields{f});
    end
end

nObservations = numel(Sort.walkingSpeed);

if size(Sort.kinematics, 2) ~= nObservations
    error(['The number of columns in Sort.kinematics must equal ', ...
        'the number of observations in Sort.walkingSpeed.']);
end

% =========================================================================
% Initialise Mean output
% =========================================================================
Mean.kinematics      = [];
Mean.kinematicsSD    = [];
Mean.walkingSpeed    = [];
Mean.stepLength      = [];
Mean.cadence         = [];
Mean.IFS1            = [];
Mean.IFS2            = [];
Mean.IFO             = [];
Mean.CFS             = [];
Mean.CFO             = [];
Mean.age             = [];
Mean.sex             = [];
Mean.BMI             = [];
Mean.LL              = [];

% Mean.sex is retained for compatibility with the original code.
% With coding 0 = female and 1 = male, Mean.sex is the proportion male
% among the observations included in each speed bin.

% =========================================================================
% Initialise Population output
% =========================================================================
Population = struct();

Population.velocity       = [];
Population.NObservations  = [];

Population.RMSE = struct('mean', {}, 'std', {});
Population.R2   = struct('mean', {}, 'std', {});
Population.MAX  = struct('mean', {}, 'std', {});
Population.VAF  = struct('mean', {}, 'std', {});

% =========================================================================
% Compute descriptive data for independent Froude-speed bins
% =========================================================================
j = 1;

for v = minVf:stepVf:maxVf

    % ---------------------------------------------------------------------
    % Identify observations belonging to the current speed bin
    %
    % This reproduces the original inclusion rule:
    %     abs(observed speed - bin centre) < half the bin width
    %
    % Importantly, idx is recalculated for every bin, so observations from
    % earlier bins cannot accumulate in later bins.
    % ---------------------------------------------------------------------
    idx = abs(Sort.walkingSpeed - v) < (stepVf / 2);

    if ~any(idx)
        continue;
    end

    % ---------------------------------------------------------------------
    % Extract data for this speed bin only
    % ---------------------------------------------------------------------
    binKinematics   = Sort.kinematics(:, idx);
    binWalkingSpeed = Sort.walkingSpeed(idx);
    binStepLength   = Sort.stepLength(idx);
    binCadence      = Sort.cadence(idx);
    binIFS1         = Sort.IFS1(idx);
    binIFS2         = Sort.IFS2(idx);
    binIFO          = Sort.IFO(idx);
    binCFS          = Sort.CFS(idx);
    binCFO          = Sort.CFO(idx);
    binAge          = Sort.age(idx);
    binSex          = Sort.sex(idx);
    binBMI          = Sort.BMI(idx);
    binLL           = Sort.LL(idx);

    nBin = size(binKinematics, 2);

    % ---------------------------------------------------------------------
    % Compute speed-bin mean values
    % ---------------------------------------------------------------------
    Mean.kinematics(:, j) = ...
        mean(binKinematics, 2, 'omitnan');

    Mean.kinematicsSD(:, j) = ...
        std(binKinematics, 0, 2, 'omitnan');

    Mean.walkingSpeed(j) = mean(binWalkingSpeed, 'omitnan');
    Mean.stepLength(j)   = mean(binStepLength, 'omitnan');
    Mean.cadence(j)      = mean(binCadence, 'omitnan');

    Mean.IFS1(j) = mean(binIFS1, 'omitnan');
    Mean.IFS2(j) = mean(binIFS2, 'omitnan');
    Mean.IFO(j)  = mean(binIFO, 'omitnan');
    Mean.CFS(j)  = mean(binCFS, 'omitnan');
    Mean.CFO(j)  = mean(binCFO, 'omitnan');

    Mean.age(j) = mean(binAge, 'omitnan');
    Mean.sex(j) = mean(binSex, 'omitnan');
    Mean.BMI(j) = mean(binBMI, 'omitnan');
    Mean.LL(j)  = mean(binLL, 'omitnan');

    % ---------------------------------------------------------------------
    % Initialise descriptive metrics for the current bin
    % ---------------------------------------------------------------------
    iRMSE = nan(1, nBin);
    iR2   = nan(1, nBin);
    iMAX  = nan(1, nBin);
    iVAF  = nan(1, nBin);

    meanCurve = Mean.kinematics(:, j);

    % ---------------------------------------------------------------------
    % Compare each observation with the speed-bin mean waveform
    % ---------------------------------------------------------------------
    for i = 1:nBin

        observedCurve = binKinematics(:, i);
        errorCurve    = observedCurve - meanCurve;

        validError = ~isnan(errorCurve);
        validCurve = ~isnan(observedCurve);

        % RMSE
        if any(validError)
            iRMSE(i) = sqrt(mean( ...
                errorCurve(validError).^2, ...
                'omitnan'));

            % Correct maximum absolute error
            iMAX(i) = max(abs(errorCurve(validError)));
        end

        % R-squared
        if any(validCurve)
            observedMean = mean( ...
                observedCurve(validCurve), ...
                'omitnan');

            ssTotal = sum( ...
                (observedCurve(validCurve) - observedMean).^2, ...
                'omitnan');

            commonValid = validError & validCurve;

            if ssTotal > eps && any(commonValid)
                ssError = sum( ...
                    errorCurve(commonValid).^2, ...
                    'omitnan');

                iR2(i) = 1 - (ssError / ssTotal);
            else
                iR2(i) = NaN;
            end
        end

        % Variance accounted for
        commonValid = validError & validCurve;

        if sum(commonValid) > 1
            observedVariance = var( ...
                observedCurve(commonValid), ...
                0, ...
                'omitnan');

            errorVariance = var( ...
                errorCurve(commonValid), ...
                0, ...
                'omitnan');

            if observedVariance > eps
                iVAF(i) = ...
                    (1 - errorVariance / observedVariance) * 100;
            else
                iVAF(i) = NaN;
            end
        end

    end

    % ---------------------------------------------------------------------
    % Store descriptive statistics for this speed bin
    % ---------------------------------------------------------------------
    Population.velocity(j) = v;
    Population.NObservations(j) = nBin;

    Population.RMSE(j).mean = mean(iRMSE, 'omitnan');
    Population.RMSE(j).std  = std(iRMSE, 0, 'omitnan');

    Population.R2(j).mean = mean(iR2, 'omitnan');
    Population.R2(j).std  = std(iR2, 0, 'omitnan');

    Population.MAX(j).mean = mean(iMAX, 'omitnan');
    Population.MAX(j).std  = std(iMAX, 0, 'omitnan');

    Population.VAF(j).mean = mean(iVAF, 'omitnan');
    Population.VAF(j).std  = std(iVAF, 0, 'omitnan');

    j = j + 1;

end

end


%%  ORIGINAL
% % =========================================================================
% % =========================================================================
% % FIT NORMAL GAIT: Predict kinematics based on walking speed, age, sex, BMI
% % =========================================================================
% % Function: computeMean
% % =========================================================================
% % Authors: F. Moissenet
% % Creation: 06 July 2017
% % Version: v1.0
% % =========================================================================
% % =========================================================================
% 
% function [Mean,Population] = computeMean(Sort,minVf,maxVf,stepVf)
% 
% % =========================================================================
% % Initialisation
% % =========================================================================
% Mean.kinematics = [];
% Mean.walkingSpeed = [];
% Mean.stepLength = [];
% Mean.cadence = [];
% Mean.IFS1 = [];
% Mean.IFS2 = [];
% Mean.IFO = [];
% Mean.CFS = [];
% Mean.CFO = [];
% Mean.age = [];
% Mean.sex = [];
% Mean.BMI = [];
% 
% % =========================================================================
% % Compute mean values data per % of the Froude velocity
% % =========================================================================
% temp1 = [];
% temp2 = [];
% temp3 = [];
% temp4 = [];
% temp5 = [];
% temp6 = [];
% temp7 = [];
% temp8 = [];
% temp9 = [];
% temp10 = [];
% temp11 = [];
% temp12 = [];
% temp13 = [];
% j = 1;
% for v = minVf:stepVf:maxVf
% 
%     % Find a velocity closed to a Froud velocity
%     % ---------------------------------------------------------------------
%     sSpeed = [];
%     for i = 1:length(Sort.walkingSpeed)
%         if abs(Sort.walkingSpeed(i)-v) < stepVf/2
%             temp1 = [temp1 Sort.kinematics(:,i)];
%             temp2 = [temp2 Sort.walkingSpeed(i)];
%             temp3 = [temp3 Sort.stepLength(i)];
%             temp4 = [temp4 Sort.cadence(i)];
%             temp5 = [temp5 Sort.IFS1(i)];
%             temp6 = [temp6 Sort.IFS2(i)];
%             temp7 = [temp7 Sort.IFO(i)];
%             temp8 = [temp8 Sort.CFS(i)];
%             temp9 = [temp9 Sort.CFO(i)];
%             temp10 = [temp10 Sort.age(i)];
%             temp11 = [temp11 Sort.sex(i)];
%             temp12 = [temp12 Sort.BMI(i)];
%             temp12 = [temp13 Sort.LL(i)];
%         end
%     end
% 
%     % Compute mean
%     % ---------------------------------------------------------------------
%     if ~isempty(temp1)
%         Mean.kinematics(:,j) = mean(temp1,2);
%         Mean.walkingSpeed(:,j) = mean(temp2,2);
%         Mean.stepLength(:,j) = mean(temp3,2);
%         Mean.cadence(:,j) = mean(temp4,2);
%         Mean.IFS1(:,j) = mean(temp5,2);
%         Mean.IFS2(:,j) = mean(temp6,2);
%         Mean.IFO(:,j) = mean(temp7,2);
%         Mean.CFS(:,j) = mean(temp8,2);
%         Mean.CFO(:,j) = mean(temp9,2);
%         Mean.age(:,j) = mean(temp10,2);
%         Mean.sex(:,j) = mean(temp11,2);
%         Mean.BMI(:,j) = mean(temp12,2);
%         Mean.LL(:,j) = mean(temp13,2);
%     end
% 
%     % Compute descriptive statistics
%     % ---------------------------------------------------------------------
%     if ~isempty(temp1)
%         for i = 1:size(temp1,2)
%             iRMSE(i) = sqrt(mean((temp1(:,i)-Mean.kinematics(:,j)).^2));
%             iR2(i) = 1 - sum((temp1(:,i)-Mean.kinematics(:,j)).^2)/...
%                 sum((temp1(:,i)-mean(temp1(:,i),1)).^2);
%             iMAX(i) = abs(max(temp1(:,i)-Mean.kinematics(:,j)));
%             iVAF(i) = (1-var(temp1(:,i)-Mean.kinematics(:,j))/var(temp1(:,i)))*100;
%         end
%         Population.velocity(j) = v;
%         Population.RMSE(j).mean = mean(iRMSE);
%         Population.RMSE(j).std = std(iRMSE);
%         Population.R2(j).mean = mean(iR2);
%         Population.R2(j).std = std(iR2);
%         Population.MAX(j).mean = mean(iMAX);
%         Population.MAX(j).std = std(iMAX);
%         Population.VAF(j).mean = mean(iVAF);
%         Population.VAF(j).std = std(iVAF);
%         j = j+1;
%     end
% 
% end