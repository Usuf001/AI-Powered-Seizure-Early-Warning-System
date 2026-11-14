function noisy = addNoise(windows, snrDb)
% ADDNOISE  Add white Gaussian noise to EEG windows at a given signal-to-noise ratio.
%   noisy = addNoise(windows, 10)     10 dB: noise power is 1/10 of signal power
%   noisy = addNoise(windows, Inf)    returns the windows unchanged
%
% windows is windows x channels x samples. The noise level is set separately for
% every channel of every window, so weak and strong channels are both affected.
% Lower snrDb means noisier. Set rng(42) before calling for repeatable results.

    if isinf(snrDb), noisy = windows; return; end
    w = double(windows);
    signalPower = mean(w .^ 2, 3);                  % windows x channels
    noisePower  = signalPower / 10 ^ (snrDb / 10);
    noisy = single(w + randn(size(w)) .* sqrt(noisePower));
end
