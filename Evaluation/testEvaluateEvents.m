function testEvaluateEvents()
% TESTEVALUATEEVENTS  Check evaluateEvents on made-up data with known answers.
% Run this first. If every test passes, the rules are implemented as in the README.

    opts = struct('threshold', 0.5, 'consecutive', 3, 'windowSec', 5, 'stepSec', 2.5);
    s = (0:1438)' * 2.5;                         % a one-hour recording
    ov = max(0, min(1060, s + 5) - max(1000, s)); % seizure from 1000 s to 1060 s
    lab = double(ov / 5 >= 0.5);
    fn = repmat("f1", numel(s), 1);

    % 1. Perfect predictor: detected, no false alarms, latency 10 s
    r = evaluateEvents(lab, lab, s, fn, opts);
    assert(r.nSeizures == 1 && r.nDetected == 1, 'T1: seizure count');
    assert(r.sensitivity == 1 && r.falseAlarms == 0, 'T1: sensitivity or false alarms');
    assert(abs(r.medianLatencySec - 10) < 1e-6, 'T1: latency should be 10 s');

    % 2. Misses everything: sensitivity 0, no false alarms
    r = evaluateEvents(zeros(size(lab)), lab, s, fn, opts);
    assert(r.sensitivity == 0 && r.falseAlarms == 0, 'T2');

    % 3. Perfect plus one false burst (3 windows high at 2000 s): one false alarm
    sc = lab;  sc(s >= 2000 & s <= 2005) = 1;
    r = evaluateEvents(sc, lab, s, fn, opts);
    assert(r.falseAlarms == 1, 'T3: one false alarm expected');
    expectedHours = (3600 - 65) / 3600;
    assert(abs(r.hoursSeizureFree - expectedHours) < 1e-9, 'T3: seizure-free hours');
    assert(abs(r.falseAlarmsPerHour - 1 / expectedHours) < 1e-9, 'T3: false alarms per hour');

    % 4. Only two windows high in a row: no alert
    sc = zeros(size(lab));  sc(s == 2000 | s == 2002.5) = 1;
    r = evaluateEvents(sc, lab, s, fn, opts);
    assert(r.falseAlarms == 0, 'T4: two windows must not trigger an alert');

    % 5. High windows split across two files must not join into one alert
    t2 = [(0:9)'; (0:9)'] * 2.5;
    f2 = [repmat("A", 10, 1); repmat("B", 10, 1)];
    sc = zeros(20, 1);  sc([9 10 11]) = 1;       % last 2 of A, first 1 of B
    r = evaluateEvents(sc, zeros(20, 1), t2, f2, opts);
    assert(r.falseAlarms == 0, 'T5: alerts must not span files');

    disp('All evaluateEvents tests passed.');
end
