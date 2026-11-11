function devRun()
% DEVRUN  First end-to-end test: features -> Random Forest -> risk scores.
%
% DEVELOPMENT ONLY. Trains on chb01 + chb05 and tests on chb14, just to prove
% the pipeline runs from start to finish. chb14 is a training patient in the
% final plan, so using it here is fine. NEVER touch chb03 or chb18 here: they
% are the final test patients.
%
% The chb14 windows were subsampled at build time (about 10 seizure-free windows
% per seizure window), so false alarms per hour cannot be measured here. This
% script only reports window-level numbers.

    cfg = config();
    rng(42);
    trainIDs = {'chb01', 'chb05'};
    testID   = 'chb14';

    Ttrain = vertcat(loadFeat(cfg, trainIDs{1}), loadFeat(cfg, trainIDs{2}));
    Ttest  = loadFeat(cfg, testID);

    meta = {'patientID', 'fileName', 'windowStartSec', 'label'};
    featCols = ~ismember(Ttrain.Properties.VariableNames, meta);

    fprintf('Train: %d windows (%d seizure). Test: %d windows (%d seizure)\n', ...
            height(Ttrain), sum(Ttrain.label), height(Ttest), sum(Ttest.label));

    mdl = fitcensemble(Ttrain(:, featCols), Ttrain.label, 'Method', 'Bag', ...
                       'NumLearningCycles', 200, ...
                       'Learners', templateTree('MinLeafSize', 5));

    [~, score] = predict(mdl, Ttest(:, featCols));
    risk = score(:, mdl.ClassNames == 1);            % seizure probability, 0 to 1

    y = Ttest.label;
    [~, ~, ~, auc] = perfcurve(y, risk, 1);
    fprintf('\nWindow-level results on %s (threshold 0.5):\n', testID);
    fprintf('  AUC:                 %.3f\n', auc);
    fprintf('  Seizure windows hit: %.1f%%\n', 100 * mean(risk(y == 1) >= 0.5));
    fprintf('  Normal windows OK:   %.1f%%\n', 100 * mean(risk(y == 0) <  0.5));

    names = Ttrain.Properties.VariableNames(featCols);
    [imp, ord] = sort(predictorImportance(mdl), 'descend');
    fprintf('\nTop 10 features:\n');
    for k = 1:10
        fprintf('  %-22s %.4f\n', names{ord(k)}, imp(ord(k)));
    end
end

function T = loadFeat(cfg, id)
    S = load(fullfile(cfg.dataRoot, 'features', [id '.mat']), 'T');
    T = S.T;
end
