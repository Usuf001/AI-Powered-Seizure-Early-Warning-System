function [thr, info] = tuneThreshold(R, targetSpecificity)
% TUNETHRESHOLD  Pick the alert threshold using TRAINING patients only.
%   R = looPatientScores();             % leave-one-patient-out scores
%   [thr, info] = tuneThreshold(R, 0.99);
%
% Chooses the lowest threshold that keeps at least targetSpecificity of the
% seizure-free windows below it (default 0.99), which gives the best sensitivity
% for that false-alarm level. Requires only the columns label and risk.
%
% NOTE: training patients were subsampled (about 10 seizure-free windows per
% seizure window), so false alarms per hour cannot be measured here. Window
% specificity is the tuning target instead. The final threshold is locked in
% config.m by the Lead on day 11, before the test patients are used.

    if nargin < 2 || isempty(targetSpecificity), targetSpecificity = 0.99; end
    risk = R.risk;  y = R.label;
    neg = risk(y == 0);  pos = risk(y == 1);

    cand = unique([risk; 1]);                   % ascending candidate thresholds
    spec = arrayfun(@(c) mean(neg < c), cand);
    k = find(spec >= targetSpecificity, 1, 'first');
    thr = cand(k);

    info.threshold   = thr;
    info.targetSpec  = targetSpecificity;
    info.specificity = spec(k);
    info.sensitivity = mean(pos >= thr);
    fprintf('Threshold %.3f: window specificity %.3f, window sensitivity %.3f\n', ...
            thr, info.specificity, info.sensitivity);
end
