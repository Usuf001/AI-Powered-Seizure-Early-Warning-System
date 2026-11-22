function R = scoreRecording(edfFiles, varargin)
% SCORERECORDING  Score NEW, unlabelled EEG recording(s) with the final model.
%   R = scoreRecording('C:\path\recording.edf')
%   R = scoreRecording({'a.edf', 'b.edf'}, 'Name', 'patient01', 'OutDir', 'C:\reports')
%
% No annotation file is needed. For each recording the function reads the EDF,
% filters and windows it, extracts the 126 features, rescales them using the
% recording(s) themselves as the patient's baseline, scores every window with the
% final model, and applies the locked alert rule (N windows in a row at or above
% the threshold). It prints a summary and returns the alerts to review.
%
% Options (name, value):
%   'Name'              patient label (default 'newpatient'). Give ALL files of one
%                       patient in a single call: they share one baseline.
%   'Threshold'         alert threshold (default cfg.alertThreshold)
%   'OutDir'            folder for alerts.csv, windows.csv and a risk plot (default none)
%   'Plot'              show the risk plot (default true)
%   'SaveForDashboard'  also save Data/processed and Data/features files so the
%                       dashboard can replay this recording (default false)
%
% Returns a struct R: hoursAnalysed, nAlerts, alertsPerHour, alerts (table),
% windows (table), threshold.
%
% Screening aid only: a clinician must review each alert on the raw EEG.
% Use the patient's WHOLE session (about an hour or more): the rescaling needs a
% reasonable amount of that patient's normal EEG as its baseline.

    cfg = config();
    p = inputParser;
    addParameter(p, 'Name', 'newpatient');
    addParameter(p, 'Threshold', cfg.alertThreshold);
    addParameter(p, 'OutDir', '');
    addParameter(p, 'Plot', true);
    addParameter(p, 'SaveForDashboard', false);
    parse(p, varargin{:});
    name = char(p.Results.Name);
    thr = p.Results.Threshold;
    outDir = char(p.Results.OutDir);
    saveDash = p.Results.SaveForDashboard;
    if isempty(thr)
        error('scoreRecording:threshold', ...
            'No alert threshold. Lock cfg.alertThreshold in config.m or pass ''Threshold''.');
    end
    nCons = cfg.alertConsecutiveWindows;
    winSec = cfg.windowSec;
    stepSec = cfg.stepSec;

    files = string(edfFiles);  files = files(:);
    assert(all(isfile(files)), 'File not found: %s', strjoin(files(~isfile(files)), ', '));
    names = strings(numel(files), 1);
    for i = 1:numel(files)
        [~, nm, ext] = fileparts(files(i));
        names(i) = string(nm) + string(ext);
    end
    names = matlab.lang.makeUniqueStrings(names);

    loaded = load(fullfile(cfg.dataRoot, 'models', 'rf_final.mat'), 'model');
    model = loaded.model;

    % ---- read and describe every recording ----
    parts = cell(numel(files), 1);
    winCell = cell(numel(files), 1);
    for i = 1:numel(files)
        fprintf('Reading %s ...\n', names(i));
        [W, st] = readEdfWindows(files(i), cfg);
        parts{i} = windowFeatures(W, st, name, names(i), cfg);
        if saveDash, winCell{i} = W; end
        fprintf('  %d windows (%.1f min)\n', size(W, 1), (st(end) + winSec) / 60);
        clear W
    end
    T = vertcat(parts{:});
    if isfield(model, 'normalize') && model.normalize && height(T) < 600
        warning(['Only %d windows (about %.0f min). The per-patient rescaling needs a ' ...
                 'longer recording to set a reliable baseline, so treat the scores with caution.'], ...
                height(T), height(T) * stepSec / 60);
    end

    % ---- score ----
    risk = predictRisk(model, T);

    % ---- alerts: same rule as the evaluation (N windows in a row at or above threshold) ----
    alFile = strings(0, 1);  alTime = zeros(0, 1);  alMean = zeros(0, 1);  alPeak = zeros(0, 1);
    active = false(height(T), 1);
    totalSec = 0;
    for i = 1:numel(names)
        rows = find(T.fileName == names(i));
        [ts, ord] = sort(T.windowStartSec(rows));
        rows = rows(ord);  rr = risk(rows);
        run = 0;
        for q = 1:numel(rows)
            if rr(q) >= thr, run = run + 1; else, run = 0; end
            active(rows(q)) = run >= nCons;
            if run == nCons
                alFile(end+1, 1) = names(i);                         %#ok<AGROW>
                alTime(end+1, 1) = ts(q) + winSec;                   %#ok<AGROW>
                alMean(end+1, 1) = mean(rr(q - nCons + 1:q));        %#ok<AGROW>
                alPeak(end+1, 1) = max(rr(max(1, q - nCons + 1):min(numel(rr), q + 6))); %#ok<AGROW>
            end
        end
        totalSec = totalSec + (ts(end) - ts(1) + winSec);
    end
    hours = totalSec / 3600;
    alTimeHMS = arrayfun(@toHMS, alTime, 'UniformOutput', false);
    alerts = table(alFile, alTime, string(alTimeHMS(:)), alMean, alPeak, ...
        'VariableNames', {'file', 'alertTimeSec', 'alertTimeHMS', 'meanRisk', 'peakRisk'});
    windows = table(T.fileName, T.windowStartSec, risk, active, ...
        'VariableNames', {'file', 'windowStartSec', 'risk', 'alertActive'});

    R = struct('threshold', thr, 'hoursAnalysed', hours, 'nAlerts', height(alerts), ...
               'alertsPerHour', height(alerts) / hours, 'alerts', alerts, 'windows', windows);

    % ---- report ----
    fprintf('\n=== %s: %.2f hours analysed, threshold %.2f ===\n', name, hours, thr);
    fprintf('%d alerts (%.2f per hour). Review each one on the raw EEG.\n', ...
            height(alerts), height(alerts) / hours);
    if height(alerts) > 0, disp(alerts); end
    fprintf('Screening aid only: a clinician must confirm every alert.\n');

    if ~isempty(outDir)
        if ~isfolder(outDir), mkdir(outDir); end
        writetable(alerts, fullfile(outDir, [name '_alerts.csv']));
        writetable(windows, fullfile(outDir, [name '_windows.csv']));
        fprintf('Saved %s_alerts.csv and %s_windows.csv in %s\n', name, name, outDir);
    end
    if p.Results.Plot || ~isempty(outDir)
        fig = plotRisk(windows, alerts, names, thr, winSec, name, p.Results.Plot);
        if ~isempty(outDir)
            exportgraphics(fig, fullfile(outDir, [name '_risk.png']), 'Resolution', 150);
        end
    end

    if saveDash
        if ~isfolder(cfg.processedDir), mkdir(cfg.processedDir); end
        fdir = fullfile(cfg.dataRoot, 'features');
        if ~isfolder(fdir), mkdir(fdir); end
        windowsAll = cat(1, winCell{:}); %#ok<NASGU>
        labels = zeros(height(T), 1); %#ok<NASGU>
        windowStartSec = T.windowStartSec; %#ok<NASGU>
        fileName = T.fileName; %#ok<NASGU>
        patientID = name; %#ok<NASGU>
        fs = cfg.fs; %#ok<NASGU>
        channelNames = cfg.channelNames; %#ok<NASGU>
        skippedFiles = strings(0, 1); %#ok<NASGU>
        windows = windowsAll; %#ok<NASGU>
        save(fullfile(cfg.processedDir, [name '.mat']), 'windows', 'labels', 'windowStartSec', ...
             'fileName', 'patientID', 'fs', 'channelNames', 'skippedFiles', '-v7.3');
        save(fullfile(fdir, [name '.mat']), 'T');
        fprintf('Saved for the dashboard: open AtlasDashboard and choose "%s".\n', name);
    end
end

function T = windowFeatures(W, st, patientID, fileName, cfg)
% Feature table for one recording's windows (label column is 0: unknown).
    chunk = 500;
    parts = {};
    for i1 = 1:chunk:size(W, 1)
        i2 = min(i1 + chunk - 1, size(W, 1));
        parts{end+1} = extractFeatures(W(i1:i2, :, :), cfg.fs, cfg.channelNames); %#ok<AGROW>
    end
    F = vertcat(parts{:});
    n = size(W, 1);
    meta = table(repmat(string(patientID), n, 1), repmat(string(fileName), n, 1), st, zeros(n, 1), ...
                 'VariableNames', {'patientID', 'fileName', 'windowStartSec', 'label'});
    T = [meta F];
end

function s = toHMS(t)
    s = sprintf('%02d:%02d:%02d', floor(t / 3600), floor(mod(t, 3600) / 60), floor(mod(t, 60)));
end

function fig = plotRisk(windows, alerts, names, thr, winSec, name, visible)
    n = numel(names);
    fig = figure('Color', 'w', 'Position', [100 100 1100 160 + 150 * min(n, 6)], ...
                 'Visible', char(ifelse(visible, 'on', 'off')));
    tl = tiledlayout(fig, min(n, 6), 1, 'TileSpacing', 'compact');
    title(tl, sprintf('%s: seizure risk and alerts (threshold %.2f)', name, thr), 'Interpreter', 'none');
    for i = 1:min(n, 6)
        ax = nexttile(tl);  hold(ax, 'on');
        w = windows(windows.file == names(i), :);
        [t, o] = sort(w.windowStartSec);
        area(ax, t + winSec, w.risk(o), 'FaceColor', [0.23 0.36 0.99], 'FaceAlpha', 0.15, ...
             'EdgeColor', [0.23 0.36 0.99]);
        yline(ax, thr, '--', 'Color', [1 0.48 0.27]);
        a = alerts(alerts.file == names(i), :);
        plot(ax, a.alertTimeSec, ones(height(a), 1) * 1.04, 'v', 'Color', [0.85 0.19 0.15], ...
             'MarkerFaceColor', [0.85 0.19 0.15]);
        ylim(ax, [0 1.1]);  ylabel(ax, 'risk');  title(ax, names(i), 'Interpreter', 'none');
        box(ax, 'off');  grid(ax, 'on');
    end
    xlabel(tl, 'seconds into recording');
end

function out = ifelse(cond, a, b)
    if cond, out = a; else, out = b; end
end
