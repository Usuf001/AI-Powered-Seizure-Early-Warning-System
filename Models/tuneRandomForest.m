function R = tuneRandomForest()
% TUNERANDOMFOREST  Try Random Forest settings with leave-one-patient-out testing.
%   R = tuneRandomForest()
% For each setting, trains on three training patients and scores the fourth, for
% every patient in turn, then prints the AUC per held-out patient. Pick the setting
% with the best mean AUC, but also look at the worst patient. Training patients
% only. If you change trainModel, use the winning values there.

    cfg = config();
    rng(42);
    ids = cfg.trainPatients;
    T = cell(numel(ids), 1);
    for i = 1:numel(ids)
        S = load(fullfile(cfg.dataRoot, 'features', [ids{i} '.mat']), 'T');
        T{i} = S.T;
    end
    cols = featureColumns(T{1});

    minLeaf = [20 50 100];
    trees   = 300;
    rows = struct('minLeaf', {}, 'trees', {}, 'meanAUC', {}, 'worstAUC', {});
    fprintf('Held-out order: %s\n', strjoin(ids, ', '));
    for a = 1:numel(minLeaf)
        for b = 1:numel(trees)
            aucs = zeros(1, numel(T));
            for i = 1:numel(T)
                tr = vertcat(T{setdiff(1:numel(T), i)});
                X = tr{:, cols};  X(~isfinite(X)) = 0;
                mdl = fitcensemble(X, double(tr.label), 'Method', 'Bag', ...
                    'NumLearningCycles', trees(b), ...
                    'Learners', templateTree('MinLeafSize', minLeaf(a)), ...
                    'ClassNames', [0 1]);
                Xt = T{i}{:, cols};  Xt(~isfinite(Xt)) = 0;
                [~, sc] = predict(mdl, Xt);
                [~, ~, ~, aucs(i)] = perfcurve(T{i}.label, sc(:, 2), 1);
            end
            rows(end+1) = struct('minLeaf', minLeaf(a), 'trees', trees(b), ...
                'meanAUC', mean(aucs), 'worstAUC', min(aucs)); %#ok<AGROW>
            fprintf('minLeaf %2d, trees %3d: AUC per patient %s, mean %.3f\n', ...
                minLeaf(a), trees(b), mat2str(round(aucs, 3)), mean(aucs));
        end
    end
    R = struct2table(rows);
end
