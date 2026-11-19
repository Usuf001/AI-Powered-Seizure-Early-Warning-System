function R = featureAblation()
% FEATUREABLATION  Which kinds of features matter? Drop one family at a time.
%   R = featureAblation()
% Trains the Random Forest with leave-one-patient-out testing, first with all
% features, then with each family removed (delta, theta, alpha, beta, gamma,
% lineLength, specEntropy). A big AUC drop means that family matters. Training
% patients only. Useful for the explainability section of the write-up.

    cfg = config();
    rng(42);
    ids = cfg.trainPatients;
    T = cell(numel(ids), 1);
    for i = 1:numel(ids)
        S = load(fullfile(cfg.dataRoot, 'features', [ids{i} '.mat']), 'T');
        T{i} = S.T;
    end
    meta = {'patientID', 'fileName', 'windowStartSec', 'label'};
    cols = featureColumns(T{1});
    families = {'delta', 'theta', 'alpha', 'beta', 'gamma', 'lineLength', 'specEntropy'};
    dropped = ['none', families];

    meanAUC = zeros(numel(dropped), 1);
    for k = 1:numel(dropped)
        if k == 1
            use = cols;
        else
            use = cols(~startsWith(cols, [dropped{k} '_']));
        end
        aucs = zeros(1, numel(T));
        for i = 1:numel(T)
            tr = vertcat(T{setdiff(1:numel(T), i)});
            model = trainModel(tr(:, [meta use]), 'rf');
            risk = predictRisk(model, T{i}(:, [meta use]));
            [~, ~, ~, aucs(i)] = perfcurve(T{i}.label, risk, 1);
        end
        meanAUC(k) = mean(aucs);
        fprintf('dropped %-12s mean AUC %.3f (change %+.3f)\n', ...
                dropped{k}, meanAUC(k), meanAUC(k) - meanAUC(1));
    end
    R = table(string(dropped'), meanAUC, meanAUC - meanAUC(1), ...
              'VariableNames', {'dropped', 'meanAUC', 'changeVsAll'});
end
