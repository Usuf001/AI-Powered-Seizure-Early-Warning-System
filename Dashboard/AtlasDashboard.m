function AtlasDashboard()
% ATLASDASHBOARD  Replay a recorded EEG and watch the seizure alert fire.
%   AtlasDashboard
%
% Left sidebar: choose a patient and a recording (a dot marks recordings that
% contain a seizure). Top tiles: this patient's results with the locked model and
% threshold. Centre: the EEG window by window and the risk score over the whole
% recording. Right: status, top features and an alert log that says whether each
% alert was a detection (and how fast) or a false alarm.
%
% Uses the FINAL model (Data/models/rf_final.mat) and the locked threshold from
% config.m, so the numbers match the reported results. Needs, for each patient:
%   Data/processed/<id>.mat   (windows)    Data/features/<id>.mat  (feature table)
% Use chb03 or chb18 for the demo: their recordings are complete (no missing windows).

    cfg = config();
    thr = cfg.alertThreshold;
    if isempty(thr), thr = 0.5; warning('cfg.alertThreshold is empty, using 0.5.'); end
    nCons  = cfg.alertConsecutiveWindows;
    winSec = cfg.windowSec;
    stepSec = cfg.stepSec;
    loaded = load(fullfile(cfg.dataRoot, 'models', 'rf_final.mat'), 'model');
    model = loaded.model;

    showNames = {'FP1-F7', 'F3-C3', 'C3-P3', 'P3-O1'};
    showCh = find(ismember(cfg.channelNames, showNames));
    nShow = numel(showCh);

    % ---- look: light cards on a soft grey page, dark sidebar, blue and orange accents ----
    bg = [0.945 0.953 0.973];   white = [1 1 1];      lightGrey = [0.89 0.90 0.93];
    ink = [0.09 0.11 0.20];     grey = [0.42 0.45 0.55];
    sideBg = [0.07 0.09 0.17];  sideList = [0.12 0.15 0.26];  sideText = [0.66 0.70 0.80];
    blue = [0.23 0.36 0.99];    paleBlue = [0.80 0.84 1.00];  orange = [1.00 0.48 0.27];
    paleOrange = [1.00 0.90 0.84];  red = [0.85 0.19 0.15];   green = [0.13 0.60 0.37];
    fontName = 'Helvetica';  if ispc, fontName = 'Segoe UI'; end

    % ---- state shared by all the callbacks below ----
    pm = [];  T = [];  riskAll = [];  idx = [];  ts = [];  r = [];  lab = [];
    alertOn = [];  alertFire = zeros(0, 1);  alertMsg = {};  block = [];
    eegLines = [];  marker = [];  tip = [];
    subsampled = false;  k = 1;  n = 1;  playing = false;  eegScale = 1;
    logCount = -1;  speed = 20;

    % ---- window: sidebar | content ----
    fig = uifigure('Name', 'Seizure Early-Warning · Team Atlas', ...
                   'Position', [50 40 1420 800], 'Color', bg);
    fig.CloseRequestFcn = @(~, ~) closeApp();
    root = uigridlayout(fig, [1 2]);
    root.ColumnWidth = {250, '1x'};  root.Padding = [0 0 0 0];
    root.ColumnSpacing = 0;  root.BackgroundColor = bg;

    % ---- sidebar ----
    side = uipanel(root, 'BackgroundColor', sideBg, 'BorderType', 'none');
    side.Layout.Column = 1;
    sg = uigridlayout(side, [7 1]);
    sg.RowHeight = {38, 22, 30, 36, 28, '1x', 64};
    sg.Padding = [20 24 20 18];  sg.RowSpacing = 6;  sg.BackgroundColor = sideBg;
    uilabel(sg, 'Text', 'ATLAS', 'FontName', fontName, 'FontSize', 28, ...
            'FontWeight', 'bold', 'FontColor', white);
    uilabel(sg, 'Text', 'Seizure early-warning', 'FontName', fontName, ...
            'FontSize', 12, 'FontColor', sideText);
    uilabel(sg, 'Text', 'PATIENT', 'FontName', fontName, 'FontSize', 11, ...
            'FontWeight', 'bold', 'FontColor', sideText, 'VerticalAlignment', 'bottom');
    % every patient that has both a processed and a feature file (includes new recordings
    % saved by scoreRecording with 'SaveForDashboard')
    d = dir(fullfile(cfg.processedDir, '*.mat'));
    avail = erase({d.name}, '.mat');
    avail = avail(~endsWith(avail, '_full'));
    avail = avail(cellfun(@(a) isfile(fullfile(cfg.dataRoot, 'features', [a '.mat'])), avail));
    assert(~isempty(avail), 'No patients found in %s', cfg.processedDir);
    defaultPat = 'chb03';
    if ~ismember(defaultPat, avail), defaultPat = avail{1}; end
    patDD = uidropdown(sg, 'Items', avail, ...
        'Value', defaultPat, 'FontName', fontName, 'FontSize', 14, ...
        'ValueChangedFcn', @(~, ~) onPatient());
    uilabel(sg, 'Text', 'RECORDINGS  (● = contains a seizure)', 'FontName', fontName, ...
            'FontSize', 11, 'FontWeight', 'bold', 'FontColor', sideText, ...
            'VerticalAlignment', 'bottom');
    fileList = uilistbox(sg, 'Items', {' '}, 'ItemsData', {' '}, 'FontName', fontName, ...
        'FontSize', 13, 'BackgroundColor', sideList, 'FontColor', white, ...
        'ValueChangedFcn', @(~, ~) onFile());
    uilabel(sg, 'Text', sprintf('Random Forest, rescaled features\nalert: %d windows at or above %.2f', ...
            nCons, thr), 'FontName', fontName, 'FontSize', 11, 'FontColor', sideText, ...
            'WordWrap', 'on', 'VerticalAlignment', 'bottom');

    % ---- content grid: header, tiles, charts, controls ----
    main = uigridlayout(root, [4 2]);
    main.Layout.Column = 2;
    main.RowHeight = {58, 112, '1x', 64};  main.ColumnWidth = {'1x', 340};
    main.Padding = [24 18 24 16];  main.RowSpacing = 14;  main.ColumnSpacing = 16;
    main.BackgroundColor = bg;

    hg = uigridlayout(main, [2 1]);
    hg.Layout.Row = 1;  hg.Layout.Column = [1 2];
    hg.RowHeight = {34, 20};  hg.Padding = [0 0 0 0];  hg.RowSpacing = 0;
    hg.BackgroundColor = bg;
    uilabel(hg, 'Text', 'SEIZURE EARLY-WARNING', 'FontName', fontName, 'FontSize', 26, ...
            'FontWeight', 'bold', 'FontColor', ink);
    uilabel(hg, 'Text', 'Replay of recorded EEG with the final model and the locked alert rule', ...
            'FontName', fontName, 'FontSize', 13, 'FontColor', grey);

    tg = uigridlayout(main, [1 4]);
    tg.Layout.Row = 2;  tg.Layout.Column = [1 2];
    tg.Padding = [0 0 0 0];  tg.ColumnSpacing = 14;  tg.BackgroundColor = bg;
    [t1Val, t1Pill] = makeTile(tg, 'Seizures detected', paleBlue, blue);
    [t2Val, t2Pill] = makeTile(tg, 'False alarms per hour', paleOrange, [0.75 0.30 0.10]);
    [t3Val, t3Pill] = makeTile(tg, 'Median alert delay', paleBlue, blue);
    [t4Val, t4Pill] = makeTile(tg, 'Alerts in this recording', paleBlue, blue);

    left = uigridlayout(main, [2 1]);
    left.Layout.Row = 3;  left.Layout.Column = 1;
    left.RowHeight = {'1.1x', '1x'};  left.Padding = [0 0 0 0];
    left.RowSpacing = 14;  left.BackgroundColor = bg;
    bodyEEG = makeCard(left, 'EEG', '4 of 18 channels, current 5-second window');
    axEEG = uiaxes(bodyEEG);  styleAxes(axEEG);
    bodyRisk = makeCard(left, 'Seizure risk score', ...
        'shaded = annotated seizure    triangle = alert fired    line = now');
    axRisk = uiaxes(bodyRisk);  styleAxes(axRisk);

    right = uigridlayout(main, [3 1]);
    right.Layout.Row = 3;  right.Layout.Column = 2;
    right.RowHeight = {228, '1x', 180};  right.Padding = [0 0 0 0];
    right.RowSpacing = 14;  right.BackgroundColor = bg;
    bodyStatus = makeCard(right, 'Status', '');
    gS = uigridlayout(bodyStatus, [4 1]);
    gS.RowHeight = {46, 58, 22, 22};  gS.Padding = [0 0 0 0];  gS.RowSpacing = 4;
    gS.BackgroundColor = white;
    statusLbl = uilabel(gS, 'Text', 'NORMAL', 'FontName', fontName, 'FontSize', 22, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'FontColor', white, 'BackgroundColor', green);
    riskLbl = uilabel(gS, 'Text', '0.00', 'FontName', fontName, 'FontSize', 38, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontColor', ink);
    uilabel(gS, 'Text', sprintf('current seizure risk (threshold %.2f)', thr), ...
        'FontName', fontName, 'HorizontalAlignment', 'center', 'FontColor', grey);
    alertsLbl = uilabel(gS, 'Text', 'alerts so far: 0', 'FontName', fontName, ...
        'HorizontalAlignment', 'center', 'FontColor', ink, 'FontWeight', 'bold');
    bodyFeat = makeCard(right, 'Top features', 'model-wide importance');
    axFeat = uiaxes(bodyFeat);  styleAxes(axFeat);
    bodyLog = makeCard(right, 'Alert log', '');
    logBox = uilistbox(bodyLog, 'Items', {}, 'FontName', fontName, 'FontSize', 12);

    ctrlPanel = uipanel(main, 'BackgroundColor', white, 'BorderType', 'line', ...
        'BorderColor', lightGrey, 'BorderWidth', 1);
    ctrlPanel.Layout.Row = 4;  ctrlPanel.Layout.Column = [1 2];
    ctrl = uigridlayout(ctrlPanel, [1 6]);
    ctrl.ColumnWidth = {100, 100, 56, 96, '1x', 400};
    ctrl.Padding = [14 10 14 10];  ctrl.BackgroundColor = white;
    uibutton(ctrl, 'Text', 'Play', 'FontName', fontName, 'FontWeight', 'bold', ...
        'BackgroundColor', blue, 'FontColor', white, 'ButtonPushedFcn', @(~, ~) play());
    uibutton(ctrl, 'Text', 'Pause', 'FontName', fontName, 'FontWeight', 'bold', ...
        'BackgroundColor', bg, 'FontColor', ink, 'ButtonPushedFcn', @(~, ~) pausePlay());
    uilabel(ctrl, 'Text', 'Speed', 'HorizontalAlignment', 'right', ...
        'FontName', fontName, 'FontColor', grey);
    speedDD = uidropdown(ctrl, 'Items', {'1x', '5x', '20x', '50x'}, 'Value', '20x', ...
        'FontName', fontName);
    slider = uislider(ctrl, 'Limits', [1 2], 'MajorTicks', [], 'MinorTicks', [], ...
        'ValueChangedFcn', @(src, ~) jump(round(src.Value)));
    timeLbl = uilabel(ctrl, 'Text', '', 'HorizontalAlignment', 'right', ...
        'FontName', fontName, 'FontColor', grey);

    % model-wide feature importance: the top feature in solid blue, the rest pale
    [imp, ord] = sort(predictorImportance(model.mdl), 'descend');
    top = ord(1:5);
    bh = barh(axFeat, flip(imp(1:5)), 0.62, 'FaceColor', 'flat', 'EdgeColor', 'none');
    cd = repmat(paleBlue, 5, 1);  cd(5, :) = blue;   % last bar = most important
    bh.CData = cd;
    yticks(axFeat, 1:5);
    yticklabels(axFeat, flip(model.featureNames(top)));
    axFeat.XTick = [];  axFeat.XAxis.Visible = 'off';  axFeat.YGrid = 'off';

    onPatient();

    % ================= helpers =================
    function body = makeCard(parent, titleText, subText)
        p = uipanel(parent, 'BackgroundColor', white, 'BorderType', 'line', ...
                    'BorderColor', lightGrey, 'BorderWidth', 1);
        g = uigridlayout(p, [2 1]);
        g.RowHeight = {24, '1x'};  g.Padding = [16 12 16 12];  g.RowSpacing = 6;
        g.BackgroundColor = white;
        h = uigridlayout(g, [1 2]);
        h.ColumnWidth = {'1x', '2x'};  h.Padding = [0 0 0 0];  h.BackgroundColor = white;
        uilabel(h, 'Text', titleText, 'FontName', fontName, 'FontSize', 15, ...
                'FontWeight', 'bold', 'FontColor', ink);
        uilabel(h, 'Text', subText, 'FontName', fontName, 'FontSize', 11, ...
                'FontColor', grey, 'HorizontalAlignment', 'right');
        body = uigridlayout(g, [1 1]);
        body.Padding = [0 0 0 0];  body.BackgroundColor = white;
    end

    function [valLbl, pillLbl] = makeTile(parent, caption, pillBg, pillFg)
        p = uipanel(parent, 'BackgroundColor', white, 'BorderType', 'line', ...
                    'BorderColor', lightGrey, 'BorderWidth', 1);
        g = uigridlayout(p, [3 1]);
        g.RowHeight = {20, 44, 24};  g.Padding = [18 12 18 12];  g.RowSpacing = 2;
        g.BackgroundColor = white;
        uilabel(g, 'Text', caption, 'FontName', fontName, 'FontSize', 12, 'FontColor', grey);
        valLbl = uilabel(g, 'Text', '-', 'FontName', fontName, 'FontSize', 30, ...
                         'FontWeight', 'bold', 'FontColor', ink);
        pillLbl = uilabel(g, 'Text', '', 'FontName', fontName, 'FontSize', 11, ...
                          'BackgroundColor', pillBg, 'FontColor', pillFg, ...
                          'HorizontalAlignment', 'center');
    end

    function styleAxes(ax)
        ax.Color = white;  ax.Box = 'off';  ax.FontName = fontName;  ax.FontSize = 11;
        ax.XColor = grey;  ax.YColor = grey;  ax.TickLength = [0 0];
        ax.XGrid = 'off';  ax.YGrid = 'on';  ax.GridAlpha = 0.12;  ax.GridColor = grey;
        ax.TickLabelInterpreter = 'none';
        ax.Toolbar.Visible = 'off';  disableDefaultInteractivity(ax);
    end

    % ================= callbacks =================
    function onPatient()
        pausePlay();
        pid = patDD.Value;
        dlg = uiprogressdlg(fig, 'Title', 'Loading', 'Indeterminate', 'on', ...
            'Message', ['Loading ' pid ' and scoring its windows...']);
        try
            pm = matfile(fullfile(cfg.processedDir, [pid '.mat']));
            tmp = load(fullfile(cfg.dataRoot, 'features', [pid '.mat']), 'T');
            T = tmp.T;
            assert(height(T) == size(pm, 'windows', 1), ...
                'Feature table and windows do not match for %s.', pid);
            riskAll = predictRisk(model, T);          % whole patient, so rescaling is correct

            % patient-level results with the locked threshold
            ev = evaluateEvents(riskAll, T.label, T.windowStartSec, T.fileName, ...
                                struct('threshold', thr, 'quiet', true));
            labelled = any(T.label == 1);
            gaps = 0;  pairs = 0;                          % are windows missing (subsampled)?
            for ff = unique(T.fileName, 'stable')'
                tt2 = sort(T.windowStartSec(T.fileName == ff));
                gaps = gaps + sum(diff(tt2) > stepSec + 1e-6);  pairs = pairs + numel(tt2) - 1;
            end
            patFull = pairs > 0 && gaps / pairs < 0.01;
            if labelled
                t1Val.Text = sprintf('%d of %d', ev.nDetected, ev.nSeizures);
                t1Pill.Text = sprintf('sensitivity %.0f%%', 100 * ev.sensitivity);
                t3Val.Text = sprintf('%.0f s', ev.medianLatencySec);
                t3Pill.Text = 'after seizure onset';
            else
                t1Val.Text = 'no labels';
                t1Pill.Text = 'new recording: seizures not annotated';
                t3Val.Text = 'n/a';
                t3Pill.Text = 'needs annotated seizures';
            end
            if patFull
                t2Val.Text = sprintf('%.2f', ev.falseAlarmsPerHour);
                if labelled
                    t2Pill.Text = sprintf('%d alerts in %.1f h of normal EEG', ...
                                          ev.falseAlarms, ev.hoursSeizureFree);
                else
                    t2Pill.Text = sprintf('alerts per hour (%d in %.1f h)', ...
                                          ev.falseAlarms, ev.hoursSeizureFree);
                end
            else
                t2Val.Text = 'n/a';
                t2Pill.Text = 'windows missing: use chb03 or chb18';
            end

            files = unique(T.fileName, 'stable');
            hasSz = ismember(files, unique(T.fileName(T.label == 1)));
            items = cell(numel(files), 1);
            for q = 1:numel(files)
                items{q} = char(files(q));
                if hasSz(q), items{q} = [items{q} '   ●']; end
            end
            fileList.Items = items;
            fileList.ItemsData = cellstr(files);
            first = find(hasSz, 1);
            if isempty(first), first = 1; end
            fileList.Value = char(files(first));
            close(dlg);
            onFile();
        catch err
            close(dlg);
            uialert(fig, err.message, 'Could not load patient');
        end
    end

    function onFile()
        pausePlay();
        fn = string(fileList.Value);
        rows = find(T.fileName == fn);
        [ts, ord2] = sort(T.windowStartSec(rows));
        rows = rows(ord2);
        idx = rows;  r = riskAll(rows);  lab = T.label(rows);  n = numel(rows);
        subsampled = mean(diff(ts) > stepSec + 1e-6) > 0.01;   % training patients keep only some windows

        % alert state for every window (same rule as evaluateEvents)
        run = 0;  alertOn = false(n, 1);  alertFire = zeros(0, 1);
        for q = 1:n
            if q > 1 && (ts(q) - ts(q-1)) > stepSec + 1e-6, run = 0; end
            if r(q) >= thr, run = run + 1; else, run = 0; end
            alertOn(q) = run >= nCons;
            if run == nCons, alertFire(end+1, 1) = ts(q) + winSec; end %#ok<AGROW>
        end

        % say what each alert was: detection (with delay) or false alarm
        blocks = findBlocks(ts, lab == 1, stepSec);
        szOn = ts(blocks(:, 1));  szOff = ts(blocks(:, 2)) + winSec;
        seen = false(size(szOn));
        alertMsg = cell(numel(alertFire), 1);
        nDet = 0;  nFalse = 0;
        for a = 1:numel(alertFire)
            j = find(alertFire(a) >= szOn & alertFire(a) <= szOff, 1);
            if isempty(j)
                alertMsg{a} = sprintf('t = %.0f s   false alarm (no seizure annotated)', alertFire(a));
                nFalse = nFalse + 1;
            elseif ~seen(j)
                seen(j) = true;
                alertMsg{a} = sprintf('t = %.0f s   seizure detected, %.0f s after onset', ...
                                      alertFire(a), alertFire(a) - szOn(j));
                nDet = nDet + 1;
            else
                alertMsg{a} = sprintf('t = %.0f s   inside the same seizure', alertFire(a));
            end
        end
        if ~any(T.label == 1)                    % new, unannotated recording
            for a = 1:numel(alertFire)
                alertMsg{a} = sprintf('t = %.0f s   alert: review the EEG here', alertFire(a));
            end
        end
        t4Val.Text = sprintf('%d', numel(alertFire));
        t4Pill.Text = sprintf('%d detected, %d false', nDet, nFalse);
        if ~any(T.label == 1), t4Pill.Text = 'review each on the raw EEG'; end

        % read this recording's windows once (rows of one file are consecutive)
        block = pm.windows(idx(1):idx(end), :, :);
        pick = unique(round(linspace(1, n, min(n, 40))));
        vals = zeros(numel(pick), 1);
        for q = 1:numel(pick)
            vals(q) = median(std(double(squeeze(block(pick(q), showCh, :))), 0, 2));
        end
        eegScale = 4 * median(vals);

        % EEG axes
        cla(axEEG);  hold(axEEG, 'on');
        tt = (0:winSec * cfg.fs - 1) / cfg.fs;
        eegLines = gobjects(nShow, 1);
        for c = 1:nShow
            eegLines(c) = plot(axEEG, tt, nan(size(tt)), 'Color', ink, 'LineWidth', 0.9);
        end
        axEEG.YLim = [0 (nShow + 1) * eegScale];  axEEG.XLim = [0 winSec];
        yticks(axEEG, (1:nShow) * eegScale);
        yticklabels(axEEG, flip(cfg.channelNames(showCh)));   % first channel on top
        axEEG.YGrid = 'off';
        xlabel(axEEG, 'seconds within window');
        hold(axEEG, 'off');

        % risk axes
        cla(axRisk);  hold(axRisk, 'on');
        area(axRisk, ts + winSec, r, 'FaceColor', blue, 'FaceAlpha', 0.14, ...
             'EdgeColor', blue, 'LineWidth', 1.2);
        yline(axRisk, thr, '--', sprintf('alert threshold %.2f', thr), ...
              'Color', orange, 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'right', ...
              'FontSize', 11);
        for b = 1:size(blocks, 1)
            xregion(axRisk, szOn(b), szOff(b), 'FaceColor', red, 'FaceAlpha', 0.12);
            text(axRisk, szOn(b), 1.115, ' annotated seizure', 'Color', red, ...
                 'FontName', fontName, 'FontSize', 10, 'VerticalAlignment', 'top');
        end
        if ~isempty(alertFire)
            plot(axRisk, alertFire, repmat(0.98, size(alertFire)), 'v', ...
                 'Color', red, 'MarkerFaceColor', red, 'MarkerSize', 7);
        end
        marker = xline(axRisk, ts(1) + winSec, 'Color', ink, 'LineWidth', 1.6);
        tip = text(axRisk, ts(1) + winSec, 0.1, '0.00', 'BackgroundColor', ink, ...
                   'Color', white, 'Margin', 4, 'FontName', fontName, 'FontSize', 10, ...
                   'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
        axRisk.XLim = [ts(1), ts(end) + winSec];
        xlabel(axRisk, 'seconds into recording');
        hold(axRisk, 'off');

        slider.Limits = [1 max(n, 2)];
        logCount = -1;
        showWindow(1);
        axRisk.YLim = [0 1.12];  axRisk.YTick = 0:0.2:1;
    end

    function showWindow(q)
        k = q;
        x = double(squeeze(block(q, showCh, :)));
        for c = 1:nShow
            eegLines(c).YData = (x(c, :) - mean(x(c, :))) + (nShow + 1 - c) * eegScale;
        end
        tNow = ts(q) + winSec;
        marker.Value = tNow;
        tip.Position = [tNow, min(r(q) + 0.05, 0.97), 0];
        tip.String = sprintf(' %.2f ', r(q));
        riskLbl.Text = sprintf('%.2f', r(q));
        if alertOn(q)
            statusLbl.Text = 'ALERT';   statusLbl.BackgroundColor = red;
            riskLbl.FontColor = red;
        else
            statusLbl.Text = 'NORMAL';  statusLbl.BackgroundColor = green;
            riskLbl.FontColor = ink;
        end
        nFired = sum(alertFire <= tNow);
        if nFired ~= logCount
            logBox.Items = alertMsg(1:nFired);
            alertsLbl.Text = sprintf('alerts so far: %d', nFired);
            logCount = nFired;
        end
        slider.Value = q;
        timeLbl.Text = sprintf('%s   %.0f / %.0f s', fileList.Value, tNow, ts(end) + winSec);
        if subsampled
            timeLbl.Text = [timeLbl.Text '   (windows missing: use chb03 or chb18)'];
        end
        drawnow limitrate
    end

    function play()
        if playing, return, end
        playing = true;
        speed = str2double(erase(speedDD.Value, 'x'));
        if k >= n, k = 1; end
        while playing && isvalid(fig) && k <= n
            showWindow(k);
            k = k + 1;
            pause(max(stepSec / speed, 0.01));
        end
        playing = false;
    end

    function pausePlay()
        playing = false;
    end

    function jump(q)
        q = max(1, min(n, q));
        showWindow(q);
    end

    function closeApp()
        playing = false;
        delete(fig);
    end
end

function blocks = findBlocks(ts, pos, stepSec)
% Start and end index of each run of consecutive positive windows.
    blocks = zeros(0, 2);
    first = NaN;
    for q = 1:numel(pos)
        contiguous = q > 1 && (ts(q) - ts(q-1)) <= stepSec + 1e-6;
        if pos(q)
            if isnan(first)
                first = q;
            elseif ~contiguous
                blocks(end+1, :) = [first, q-1]; %#ok<AGROW>
                first = q;
            end
        elseif ~isnan(first)
            blocks(end+1, :) = [first, q-1]; %#ok<AGROW>
            first = NaN;
        end
    end
    if ~isnan(first), blocks(end+1, :) = [first, numel(pos)]; end
end
