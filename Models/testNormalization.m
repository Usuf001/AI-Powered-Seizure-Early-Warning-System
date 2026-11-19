function R = testNormalization()
% TESTNORMALIZATION  Does per-patient normalisation help across patients?
%   R = testNormalization()
% Leave-one-patient-out Random Forest AUC with raw features and with features
% normalised within each patient (normalizeByPatient). Training patients only.

    cfg = config();
    rng(42);
    ids = cfg.trainPatients;
    T = cell(numel(ids), 1);
    for i = 1:numel(ids)
        S = load(fullfile(cfg.dataRoot, 'features', [ids{i} '.mat']), 'T');
        T{i} = S.T;
    end
    Tn = cellfun(@normalizeByPatient, T, 'UniformOutput', false);

    variants = {'raw', 'normalized'};
    data = {T, Tn};
    aucs = zeros(numel(variants), numel(ids));
    for v = 1:numel(variants)
        D = data{v};
        for i = 1:numel(ids)
            model = trainModel(vertcat(D{setdiff(1:numel(ids), i)}), 'rf');
            risk = predictRisk(model, D{i});
            [~, ~, ~, aucs(v, i)] = perfcurve(D{i}.label, risk, 1);
        end
        fprintf('%-11s AUC per patient %s, mean %.3f\n', variants{v}, ...
                mat2str(round(aucs(v, :), 3)), mean(aucs(v, :)));
    end
    fprintf('Held-out order: %s\n', strjoin(ids, ', '));
    R = array2table(aucs, 'VariableNames', ids, 'RowNames', variants);
    R.mean = mean(aucs, 2);
    disp(R);
end
