function [minVf,maxVf,stepVf,vfPlotMax,vfStats] = aa_set_vf_limits_from_norm_files(File,V,stepVf)
%AA_SET_VF_LIMITS_FROM_NORM_FILES Estimate Froude velocity limits from Norm_V*.mat files.
%
% Froude velocity / non-dimensional walking speed:
%   Vf = walkingSpeed_ms / sqrt(9.81 * legLength_m)
%
% This function is for Fmoissenet-style MAIN_fitGait_v2 scripts.
% It scans File(1:V), extracts each cycle's walking speed and subject leg length,
% computes Vf, then chooses data-driven limits.
%
% Outputs:
%   minVf     lower Vf limit, rounded down to nearest stepVf
%   maxVf     upper Vf limit, rounded up to nearest stepVf from 95th percentile
%   vfPlotMax plotting limit, one step below maxVf where appropriate
%   vfStats   summary structure
%
% Usage after loading File(1:V):
%   stepVf = 0.05;
%   [minVf,maxVf,stepVf,vfPlotMax,vfStats] = aa_set_vf_limits_from_norm_files(File,V,stepVf);

if nargin < 3 || isempty(stepVf)
    stepVf = 0.05;
end

g = 9.81;
allVf = [];

for v = 1:V
    if ~isfield(File(v),'Normatives') || ~isfield(File(v).Normatives,'Kinematics')
        continue;
    end

    K = File(v).Normatives.Kinematics;
    GP = File(v).Normatives.Gaitparameters;
    Pop = File(v).Population;

    % Number of cycles in this velocity file
    if isfield(K,'sujets')
        nCycles = numel(K.sujets);
    elseif isfield(K,'FE3') && isfield(K.FE3,'data')
        nCycles = size(K.FE3.data,2);
    else
        continue;
    end

    % Get speed per cycle
    speed_ms = [];
    candidateSpeedFields = {'mean_velocity','velocity','walkingSpeed','speed'};
    for f = 1:numel(candidateSpeedFields)
        fieldName = candidateSpeedFields{f};
        if isfield(GP,fieldName) && isfield(GP.(fieldName),'data')
            speed_ms = GP.(fieldName).data;
            break;
        end
    end
    if isempty(speed_ms)
        warning('Could not find speed field in Normatives.Gaitparameters for File(%d). Skipping.', v);
        continue;
    end
    speed_ms = double(speed_ms(:)');

    % Get subject/cycle names
    sujets = string(K.sujets(:)');
    popNames = strings(1, numel(Pop.L0.data));
    if isfield(Pop,'sujets')
        popNames = string(Pop.sujets(:)');
    elseif isfield(Pop,'name')
        popNames = string(Pop.name(:)');
    else
        popNames = "S" + compose("%03d", 1:numel(Pop.L0.data));
    end

    L0cycle = nan(1,nCycles);
    for c = 1:nCycles
        idx = find(popNames == sujets(c), 1, 'first');
        if isempty(idx)
            % fallback: if subject labels do not match, use median leg length
            L0cycle(c) = median(double(Pop.L0.data), 'omitnan');
        else
            L0cycle(c) = double(Pop.L0.data(idx));
        end
    end

    usableN = min([numel(speed_ms), numel(L0cycle), nCycles]);
    vf = speed_ms(1:usableN) ./ sqrt(g .* L0cycle(1:usableN));
    vf = vf(isfinite(vf) & vf > 0);
    allVf = [allVf vf]; %#ok<AGROW>
end

if isempty(allVf)
    error('No valid Froude velocity values could be calculated from File(1:V).');
end

vfStats = struct();
vfStats.n = numel(allVf);
vfStats.min = min(allVf);
vfStats.max = max(allVf);
vfStats.mean = mean(allVf);
vfStats.median = median(allVf);
vfStats.p05 = prctile(allVf,5);
vfStats.p25 = prctile(allVf,25);
vfStats.p75 = prctile(allVf,75);
vfStats.p95 = prctile(allVf,95);
vfStats.values = allVf;

% Conservative data-driven limits:
% Lower bound: floor observed min to step.
% Upper bound: ceil 95th percentile to step, not full max, to avoid sparse edge bins.
minVf = floor(vfStats.min/stepVf) * stepVf;
maxVf = ceil(vfStats.p95/stepVf) * stepVf;

% Avoid zero lower bound unless data really starts there
if minVf < stepVf
    minVf = stepVf;
end

% Plot one bin below max if possible, like Fmoissenet used 0.75 while maxVf was 0.80.
if maxVf - stepVf > minVf
    vfPlotMax = maxVf - stepVf;
else
    vfPlotMax = maxVf;
end

fprintf('\nCalculated Froude velocity limits from our data:\n');
fprintf('  n cycles:   %d\n', vfStats.n);
fprintf('  min Vf:     %.3f\n', vfStats.min);
fprintf('  median Vf:  %.3f\n', vfStats.median);
fprintf('  95th %% Vf:  %.3f\n', vfStats.p95);
fprintf('  max Vf:     %.3f\n', vfStats.max);
fprintf('  minVf:      %.2f\n', minVf);
fprintf('  maxVf:      %.2f\n', maxVf);
fprintf('  vfPlotMax:  %.2f\n\n', vfPlotMax);

end
