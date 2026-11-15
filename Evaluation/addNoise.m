function noisy = addNoise(windows, snrDb, refPower)
% ADDNOISE  Add realistic electrode-style noise to EEG windows.
%   noisy = addNoise(windows, 10, refPower)
%   noisy = addNoise(windows, Inf)       returns the windows unchanged
%
% windows   windows x channels x samples
% snrDb     signal-to-noise ratio in dB (lower = noisier)
% refPower  1 x channels: the typical signal power of each channel for this
%           patient (see referencePower). Noise power = refPower / 10^(snrDb/10),
%           the SAME for every window, like a fixed electrode noise floor.
%           If omitted, each window's own power is used (not recommended:
%           loud, slow windows then get far more noise than quiet ones).
%
% The noise is band-limited to the project band-pass (0.5-40 Hz). The windows
% were already filtered, so unfiltered white noise would add power that the real
% pipeline would have removed, and would distort line length.
% Set rng(42) before calling for repeatable results.

    if isinf(snrDb), noisy = windows; return; end
    cfg = config();
    w = double(windows);
    [nWin, nCh, nSamp] = size(w);

    if nargin < 3 || isempty(refPower)
        refPower = mean(w .^ 2, 3);                    % windows x channels
    else
        refPower = reshape(refPower, 1, []);           % 1 x channels
    end
    noisePower = refPower / 10 ^ (snrDb / 10);

    noise = randn(nWin, nCh, nSamp);
    [z, p, k] = butter(4, cfg.bandpassHz / (cfg.fs / 2), 'bandpass');
    [sos, g] = zp2sos(z, p, k);
    nz = reshape(permute(noise, [3 1 2]), nSamp, []);  % samples x (windows*channels)
    nz = filtfilt(sos, g, nz);
    noise = permute(reshape(nz, nSamp, nWin, nCh), [2 3 1]);
    noise = noise ./ sqrt(mean(noise .^ 2, 3));        % unit power per window/channel

    noisy = single(w + noise .* sqrt(noisePower));
end
