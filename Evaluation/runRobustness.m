function R = runRobustness(trainIDs, testID, final)
% RUNROBUSTNESS  How does detection hold up with fewer channels and more noise?
%   R = runRobustness()                                  development run
%   R = runRobustness({'chb01','chb05'}, 'chb14')        same, explicit
%   R = runRobustness(cfg.trainPatients, 'chb03', true)  FINAL run (day 11 onwards)
%
% For every channel set and noise level: trains on CLEAN training data restricted
% to those channels, tests on the noisy test patient, and reports AUC, sensitivity,
% false alarms per hour and median latency. Test patients chb03 and chb18 are
% blocked unless final is true, so nobody uses them by accident.
%
% On a development patient (subsampled windows) false alarms per hour is NOT
% reliable, and evaluateEvents will warn. It is valid on the full test patients.

    cfg = config();
    rng(42);
    if nargin < 1 || isempty(trainIDs), trainIDs = {'chb01', 'chb05'}; end
    if nargin < 2 || isempty(testID),   testID = 'chb14'; end
    if nargin < 3, final = false; end
    assert(~any(ismember(trainIDs, cfg.testPatients)), 'Never train on test patients.');
    if ismember(testID, cfg.testPatients) && ~final
        error(['%s is a final test patient. Use runRobustness(trainIDs, testID, true) ' ...
               'only after the threshold is locked on day 11.'], testID);
    end
    thr = cfg.alertThreshold;
    if isempty(thr)
        thr = 0.5;
        warning('cfg.alertThreshold is empty, using 0.5 for this run.');
    end

    channelSets = struct( ...
        'name', {'all18', '8ch', '4ch'}, ...
        'channels', {cfg.channelNames, ...
                     {'FP1-F3','F3-C3','C3-P3','P3-O1','FP2-F4','F4-C4','C4-P4','P4-O2'}, ...
                     {'F3-C3','P3-O1','F4-C4','P4-O2'}});
    snrLevels = [Inf 20 10 5 0];

    Ttrain = [];
    for i = 1:numel(trainIDs)
        S = load(fullfile(cfg.dataRoot, 'features', [trainIDs{i} '.mat']), 'T');
        Ttrain = [Ttrain; S.T]; %#ok<AGROW>
    end

    fprintf('Building noisy feature tables for %s...\n', testID);
    Ttest = cell(1, numel(snrLevels));
    for k = 1:numel(snrLevels)
        Ttest{k} = buildNoisyFeatures(testID, snrLevels(k));
    end

    rows = struct('channelSet', {}, 'nChannels', {}, 'snrDb', {}, 'auc', {}, ...
                  'sensitivity', {}, 'falseAlarmsPerHour', {}, 'medianLatencySec', {});
    for c = 1:numel(channelSets)
        keep = channelSets(c).channels;
        model = trainModel(selectChannels(Ttrain, keep), 'rf');
        for k = 1:numel(snrLevels)
            T = selectChannels(Ttest{k}, keep);
            risk = predictRisk(model, T);
            [~, ~, ~, auc] = perfcurve(T.label, risk, 1);
            ev = evaluateEvents(risk, T.label, T.windowStartSec, T.fileName, ...
                                struct('threshold', thr));
            rows(end+1) = struct('channelSet', string(channelSets(c).name), ...
                'nChannels', numel(keep), 'snrDb', snrLevels(k), 'auc', auc, ...
                'sensitivity', ev.sensitivity, ...
                'falseAlarmsPerHour', ev.falseAlarmsPerHour, ...
                'medianLatencySec', ev.medianLatencySec); %#ok<AGROW>
        end
        fprintf('  %s done\n', channelSets(c).name);
    end
    R = struct2table(rows);
    disp(R);

    figure; hold on
    for c = 1:numel(channelSets)
        r = R(R.channelSet == string(channelSets(c).name), :);
        plot(1:numel(snrLevels), r.auc, '-o', 'DisplayName', ...
             sprintf('%s (%d ch)', channelSets(c).name, r.nChannels(1)));
    end
    xticks(1:numel(snrLevels));
    xticklabels(string(snrLevels));
    xlabel('SNR (dB), Inf = clean');  ylabel('AUC');
    title(sprintf('Robustness on %s', testID));
    legend('Location', 'southwest');  grid on
end
