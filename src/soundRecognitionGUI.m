function soundRecognitionGUI
%SOUNDRECOGNITIONGUI Sound Recognition and Visualization GUI.
%   CEN320/BME320 Project - Amro Kamal Jalad (1092505)
%
%   This app lets the user:
%     - record a short audio message
%     - see the time-domain waveform
%     - see the Fourier Transform (frequency spectrum)
%     - see the Power Spectrum
%     - see the Power Spectral Density
%     - see a histogram of the signal
%     - see a spectrogram (frequency content over time)
%     - read off the Energy, Max Frequency, Mean, Std, and Variance
%     - optionally filter noise before analyzing (bonus requirement)
%     - save the recording as a labeled .wav file (raw data for submission)
%     - export the whole GUI as a PNG image (for the report)
%
%   This file only builds the GUI and connects buttons to actions. The
%   actual math is done in two separate files:
%       analyzeSignal.m  - computes FFT/power spectrum/PSD/energy/stats/spectrogram
%       filterNoise.m    - the bonus noise filter
%
%   Requires: base MATLAB only, no toolboxes.

clc   % just clears the command window so old output doesn't confuse me

%% ---------------- Settings ----------------
Fs = 44100;              % sampling frequency (Hz) - standard CD quality
recTime = 5;             % default recording duration (seconds), user can change this in the GUI

%% ---------------- Shared data ----------------
% these need to be up here (not inside a function) so every callback
% below can see them and change them - this is how nested functions work
x  = [];    % raw recorded signal
xf = [];    % filtered signal (after applying the noise filter)
freqZoom = 5000;   % default frequency-axis zoom (Hz) for FFT/Power/PSD plots
                    % (5000 because that's basically where speech ends, no point showing all the way to 22050)

%% ---------------- Color theme ----------------
% just picked colors that looked decent together, nothing fancy
colAccent  = [0.16 0.42 0.80];    % header / play button blue
colRecord  = [0.82 0.20 0.20];    % record button + "recording" lamp
colGreen   = [0.16 0.60 0.34];    % save button + "ready" lamp
colIdle    = [0.75 0.75 0.75];    % lamp before anything is recorded
colCard    = [1.00 1.00 1.00];    % panel background
colReset   = [0.45 0.45 0.48];    % reset button

colTime  = [0.16 0.42 0.80];      % time-domain plot line
colFFT   = [0.47 0.24 0.66];      % FFT plot line
colPower = [0.13 0.55 0.45];      % power spectrum plot line
colPSD   = [0.85 0.55 0.10];      % PSD plot line
colHist  = [0.82 0.32 0.24];      % histogram bars
% gave each plot its own color so it's easier to tell them apart at a glance

%% ================= Main window =================
% uifigure instead of the old figure() command because it plays nice
% with uigridlayout and the newer components like uilamp, uislider etc.
fig = uifigure('Name','Sound Recognition and Visualization', ...
    'Position',[50 20 1320 960],'Color',[0.95 0.96 0.97]);

% splitting the window into 2 rows: a small header on top, everything else below
outer = uigridlayout(fig,[2 1]);
outer.RowHeight = {64,'1x'};   % header is fixed height, rest fills whatever space is left
outer.Padding = [0 0 0 0];
outer.RowSpacing = 0;

% ---- Header bar ----
header = uipanel(outer,'BackgroundColor',colAccent,'BorderType','none');
header.Layout.Row = 1;
hg = uigridlayout(header,[2 1]);
hg.RowHeight = {'1x','1x'};
hg.Padding = [18 4 18 4];
hg.RowSpacing = 0;
hg.BackgroundColor = colAccent;   % had to set this separately, the panel color alone doesn't show through the grid

uilabel(hg,'Text','Sound Recognition and Visualization', ...
    'FontSize',20,'FontWeight','bold','FontColor',[1 1 1]);
uilabel(hg,'Text','CEN320 / BME320  -  Amro Kamal Jalad (1092505)', ...
    'FontSize',12,'FontColor',[0.88 0.92 1]);

% ---- Body: sidebar + plots ----
% this is the main row, split into left (controls) and right (plots)
body = uigridlayout(outer,[1 2]);
body.Layout.Row = 2;
body.ColumnWidth = {320,'1x'};   % sidebar fixed at 320px, plots take the rest
body.Padding = [14 14 14 14];
body.ColumnSpacing = 14;

%% ================= Sidebar =================
% 4 stacked panels: Recording, Noise Filter, Save/Export, Statistics
sidebar = uigridlayout(body,[4 1]);
sidebar.Layout.Column = 1;
sidebar.RowHeight = {270,150,155,'1x'};   % had to tweak these numbers a bunch until nothing overlapped
sidebar.RowSpacing = 14;
sidebar.Padding = [0 0 0 0];

% ---- Recording panel ----
recPanel = uipanel(sidebar,'Title','Recording','FontWeight','bold','BackgroundColor',colCard);
recPanel.Layout.Row = 1;
recGrid = uigridlayout(recPanel,[5 2]);
recGrid.RowHeight = {28,34,34,34,34,26};   % 4 buttons + duration field + lamp row
recGrid.ColumnWidth = {'1x','1x'};
recGrid.RowSpacing = 6;

uilabel(recGrid,'Text','Duration (s):');
dur_field = uieditfield(recGrid,'numeric','Value',recTime,'Limits',[1 30]);
% limited to 1-30 sec so people don't accidentally record for an hour

btn_record = uibutton(recGrid,'push','Text','Record', ...
    'BackgroundColor',colRecord,'FontColor',[1 1 1],'FontWeight','bold', ...
    'ButtonPushedFcn',@record_callback);
btn_record.Layout.Column = [1 2];   % spans both columns so it's a full-width button

btn_play = uibutton(recGrid,'push','Text','Play', ...
    'BackgroundColor',colAccent,'FontColor',[1 1 1],'FontWeight','bold', ...
    'ButtonPushedFcn',@play_callback);
btn_play.Layout.Column = [1 2];

btn_reset = uibutton(recGrid,'push','Text','Reset', ...
    'BackgroundColor',colReset,'FontColor',[1 1 1],'FontWeight','bold', ...
    'ButtonPushedFcn',@reset_callback);
btn_reset.Layout.Column = [1 2];

btn_load = uibutton(recGrid,'push','Text','Load Audio File', ...
    'BackgroundColor',colAccent,'FontColor',[1 1 1],'FontWeight','bold', ...
    'ButtonPushedFcn',@load_callback);
btn_load.Layout.Column = [1 2];
% added this one later on, doctor wanted a way to check raw data files
% without needing physical drag and drop (which doesn't really work well in base matlab)

lamp = uilamp(recGrid,'Color',colIdle);   % little status light, changes color depending on what's happening
status_lbl = uilabel(recGrid,'Text','Idle','FontColor',[0.45 0.45 0.45]);

% ---- Noise filter panel (bonus) ----
filterPanel = uipanel(sidebar,'Title','Noise Filter (Bonus)','FontWeight','bold','BackgroundColor',colCard);
filterPanel.Layout.Row = 2;
filterGrid = uigridlayout(filterPanel,[4 1]);
filterGrid.RowHeight = {26,20,32,'1x'};

chk_filter = uicheckbox(filterGrid,'Text','Apply noise filter','ValueChangedFcn',@filter_callback);
strength_lbl = uilabel(filterGrid,'Text','Filter sharpness: 15');
strength_slider = uislider(filterGrid,'Limits',[3 50],'Value',15, ...
    'MajorTicks',[3 15 30 50],'ValueChangedFcn',@strength_callback);
% slider value doesn't directly = filter order, it gets converted in sliderToOrder()
% lower down. kept it 3-50 because that felt like a good "readable" range for a slider
uilabel(filterGrid,'Text','Removes hum below 150 Hz and hiss above 5000 Hz.', ...
    'FontColor',[0.55 0.55 0.55],'FontSize',11,'WordWrap','on');

% ---- Save / export panel ----
savePanel = uipanel(sidebar,'Title','Save & Export','FontWeight','bold','BackgroundColor',colCard);
savePanel.Layout.Row = 3;
saveGrid = uigridlayout(savePanel,[3 1]);
saveGrid.RowHeight = {30,34,34};

name_field = uieditfield(saveGrid,'text','Value','amro_recording');
btn_save = uibutton(saveGrid,'push','Text','Save as .wav', ...
    'BackgroundColor',colGreen,'FontColor',[1 1 1],'FontWeight','bold', ...
    'ButtonPushedFcn',@save_callback);
btn_export = uibutton(saveGrid,'push','Text','Export GUI as .png', ...
    'BackgroundColor',colAccent,'FontColor',[1 1 1],'FontWeight','bold', ...
    'ButtonPushedFcn',@export_callback);
% added export button so i don't need to alt+tab and use snipping tool every time
% for the report screenshots, saves a lot of time honestly

% ---- Statistics panel ----
statsPanel = uipanel(sidebar,'Title','Statistics','FontWeight','bold','BackgroundColor',colCard);
statsPanel.Layout.Row = 4;
statsGrid = uigridlayout(statsPanel,[7 1]);
statsGrid.RowHeight = {24,24,24,24,24,24,24};
statsGrid.RowSpacing = 4;

chk_fullspec = uicheckbox(statsGrid,'Text','Show full spectrum (0-22050 Hz)', ...
    'FontSize',11,'ValueChangedFcn',@fullspec_callback);
% by default we zoom into 0-5000Hz because that's basically all speech,
% but sometimes i wanted to see the full range so added this toggle

energy_lbl  = uilabel(statsGrid,'Text','Energy: -','FontWeight','bold');
maxfreq_lbl = uilabel(statsGrid,'Text','Max frequency: -');
mean_lbl    = uilabel(statsGrid,'Text','Mean: -');
std_lbl     = uilabel(statsGrid,'Text','Std deviation: -');
var_lbl     = uilabel(statsGrid,'Text','Variance: -');
psd_lbl     = uilabel(statsGrid,'Text','Peak PSD: -');
% all start as "-" until something actually gets recorded/loaded

%% ================= Plot area (3x2 grid of cards) =================
plotsGrid = uigridlayout(body,[3 2]);
plotsGrid.Layout.Column = 2;
plotsGrid.RowSpacing = 12;
plotsGrid.ColumnSpacing = 14;

% making 6 plot "cards" using my own helper function below (addPlotCard)
% so i don't have to copy paste the same uipanel/uiaxes code 6 times
ax_time  = addPlotCard(1,1,'Time-Domain Signal');
ax_fft   = addPlotCard(1,2,'Fourier Transform');
ax_power = addPlotCard(2,1,'Power Spectrum');
ax_psd   = addPlotCard(2,2,'Power Spectral Density');
ax_hist  = addPlotCard(3,1,'Histogram');
ax_spec  = addPlotCard(3,2,'Spectrogram');

% same deal here, using styleAxes() helper so every plot looks consistent
% instead of setting grid/box/fontsize manually 6 separate times
styleAxes(ax_time, 'Time (s)','Amplitude');
styleAxes(ax_fft,  'Frequency (Hz)','Magnitude');
styleAxes(ax_power,'Frequency (Hz)','Power');
styleAxes(ax_psd,  'Frequency (Hz)','Power');
styleAxes(ax_hist, 'Amplitude','Count');
styleAxes(ax_spec, 'Time (s)','Frequency (Hz)');
ax_spec.XGrid = 'off';   % grid lines look bad over the spectrogram heatmap, turned them off just for this one
ax_spec.YGrid = 'off';

%% ================= Callback functions =================
% everything below here only runs when the user actually clicks something,
% not when the app first opens

    function record_callback(~,~)
        % this runs when Record is clicked. records for however many
        % seconds the user set, then sends it off to be analyzed
        recTime = dur_field.Value;
        lamp.Color = colRecord;
        status_lbl.Text = 'Recording...';
        status_lbl.FontColor = colRecord;
        drawnow;   % forces the GUI to actually update NOW instead of waiting,
                   % otherwise the "Recording..." text wouldn't show up until after recording is done

        recorder = audiorecorder(Fs,16,1);   % Fs, bits per sample, mono (1 = mono, 2 would be stereo)
        recordblocking(recorder,recTime);    % "blocking" means matlab just waits here until it's done, doesn't move on
        x = getaudiodata(recorder);          % pull the actual sample numbers out of the recorder object

        lamp.Color = colGreen;
        status_lbl.Text = 'Recording complete';
        status_lbl.FontColor = colGreen;

        chk_filter.Value = false;            % new recording -> start unfiltered, don't carry over old filter state
        xf = [];
        updateDisplay(x);
    end

    function load_callback(~,~)
        % lets you pick an existing audio file off your computer instead
        % of recording live - this is what the doctor asked for so raw
        % data files could be checked independently later
        [file, path] = uigetfile({'*.wav;*.mp3;*.m4a;*.flac', ...
            'Audio Files (*.wav, *.mp3, *.m4a, *.flac)'}, 'Select an audio file');
        if isequal(file,0)
            return   % user clicked Cancel, just do nothing and stop here
        end

        try
            [loadedSig, loadedFs] = audioread(fullfile(path,file));
            if size(loadedSig,2) > 1
                loadedSig = mean(loadedSig,2);   % if it's stereo (2 columns), average them into 1 mono column
            end

            x = loadedSig;
            Fs = loadedFs;   % important - use the FILE's own sample rate, not always 44100
                              % (some files might be recorded at a different rate)

            lamp.Color = colGreen;
            status_lbl.Text = ['Loaded ' file];
            status_lbl.FontColor = colGreen;

            chk_filter.Value = false;
            xf = [];
            updateDisplay(x);
        catch ME
            % if something goes wrong (corrupt file, wrong format etc)
            % don't just crash the whole app, show an error message instead
            status_lbl.Text = 'Failed to load file';
            status_lbl.FontColor = colRecord;
            disp(ME.message);   % prints the real matlab error to the command window so I can debug it
        end
    end

    function play_callback(~,~)
        % plays back whatever is currently on screen - if the filter
        % checkbox is on, play the filtered version, otherwise play the raw one
        if isempty(x)
            status_lbl.Text = 'Nothing recorded yet';
            status_lbl.FontColor = colRecord;
            return
        end
        if chk_filter.Value && ~isempty(xf)
            sound(xf,Fs);
        else
            sound(x,Fs);
        end
    end

    function reset_callback(~,~)
        % basically puts the app back to how it was when it first opened.
        % useful when demoing so i don't have to close and reopen matlab every time
        x = [];
        xf = [];
        chk_filter.Value = false;
        lamp.Color = colIdle;
        status_lbl.Text = 'Idle';
        status_lbl.FontColor = [0.45 0.45 0.45];

        cla(ax_time); cla(ax_fft); cla(ax_power);   % cla = clear axes, wipes the plots but keeps the axes themselves
        cla(ax_psd); cla(ax_hist); cla(ax_spec);

        energy_lbl.Text  = 'Energy: -';
        maxfreq_lbl.Text = 'Max frequency: -';
        mean_lbl.Text    = 'Mean: -';
        std_lbl.Text     = 'Std deviation: -';
        var_lbl.Text     = 'Variance: -';
        psd_lbl.Text     = 'Peak PSD: -';
    end

    function filter_callback(~,~)
        % runs whenever the "Apply noise filter" checkbox gets clicked
        if isempty(x)
            chk_filter.Value = false;   % don't let them turn on filter with no recording, nothing to filter yet
            return
        end
        if chk_filter.Value
            order = sliderToOrder(strength_slider.Value);
            xf = filterNoise(x,Fs,order);   % actual filtering happens in the separate filterNoise.m file
            updateDisplay(xf);
        else
            updateDisplay(x);   % filter turned off, go back to showing the original unfiltered signal
        end
    end

    function strength_callback(~,~)
        % runs every time the sharpness slider gets dragged. if the
        % filter is already on, we re-filter right away so you can SEE
        % the change live instead of having to toggle the checkbox again
        v = round(strength_slider.Value);
        strength_lbl.Text = sprintf('Filter sharpness: %d', v);

        if ~isempty(x) && chk_filter.Value
            order = sliderToOrder(strength_slider.Value);
            xf = filterNoise(x,Fs,order);
            updateDisplay(xf);
        end
    end

    function order = sliderToOrder(v)
        % converts the slider number (3-50, easy for a human to read)
        % into an actual FIR filter order (odd number, roughly 19-301 taps)
        % higher order = sharper/more precise filter cutoff, but more computation
        order = round(v)*6 + 1;   % *6 then +1 just makes sure it's always odd, filter needs odd length
    end

    function save_callback(~,~)
        % writes whatever is currently shown (filtered or not) out to an
        % actual .wav file on disk - this is my raw data for submission
        if isempty(x)
            status_lbl.Text = 'Nothing to save yet';
            status_lbl.FontColor = colRecord;
            return
        end
        if chk_filter.Value && ~isempty(xf)
            sigToSave = xf;
        else
            sigToSave = x;
        end

        fname = [name_field.Value '.wav'];
        audiowrite(fname, sigToSave, Fs);
        status_lbl.Text = ['Saved ' fname];
        status_lbl.FontColor = colGreen;
    end

    function export_callback(~,~)
        % takes a screenshot of the whole app window and saves it as png,
        % saved me a ton of time when making screenshots for the report
        fname = [name_field.Value '_gui.png'];
        try
            exportapp(fig, fname);
            status_lbl.Text = ['Exported ' fname];
            status_lbl.FontColor = colGreen;
        catch ME
            status_lbl.Text = 'Export failed - see command window';
            status_lbl.FontColor = colRecord;
            disp(ME.message);
        end
    end

    function fullspec_callback(~,~)
        % toggles between the zoomed in view (0-5000Hz, good for
        % speech) and showing literally the whole spectrum up to Fs/2
        if chk_fullspec.Value
            freqZoom = Fs/2;
        else
            freqZoom = 5000;
        end
        % re-draw whatever's currently on screen with the new zoom level
        if ~isempty(x)
            if chk_filter.Value && ~isempty(xf)
                updateDisplay(xf);
            else
                updateDisplay(x);
            end
        end
    end

%% ================= Display helper =================
% this is the function that actually gets called every single time
% something new needs to be shown - after recording, loading, filtering,
% or even just moving the zoom checkbox

    function updateDisplay(sig)
        % takes a signal, sends it to analyzeSignal.m to get all the
        % numbers, then dumps everything onto the plots and labels

        r = analyzeSignal(sig, Fs);   % all the actual math happens over there, not here

        % Time domain
        plot(ax_time, r.t, r.sig, 'Color',colTime,'LineWidth',1.1);
        xlim(ax_time, [0 r.t(end)]);

        % Fourier Transform
        plot(ax_fft, r.f, r.mag, 'Color',colFFT,'LineWidth',1.1);
        xlim(ax_fft, [0 freqZoom]);

        % Power spectrum
        plot(ax_power, r.f, r.powerSpec, 'Color',colPower,'LineWidth',1.1);
        xlim(ax_power, [0 freqZoom]);

        % Power spectral density
        plot(ax_psd, r.f, r.psd, 'Color',colPSD,'LineWidth',1.1);
        xlim(ax_psd, [0 freqZoom]);

        % Histogram - 50 bins looked like a good balance, not too
        % blocky and not too noisy
        histogram(ax_hist, r.sig, 50, 'FaceColor',colHist,'EdgeColor','none');

        % Spectrogram (frequency content over time)
        % using dB scale (20*log10) because otherwise the loud parts
        % totally wash out the quiet parts and you can't see anything
        imagesc(ax_spec, r.specT, r.specF, 20*log10(r.specData + eps));
        set(ax_spec,'YDir','normal');   % without this the spectrogram shows upside down for some reason
        colormap(ax_spec,'parula');
        ylim(ax_spec,[0 8000]);   % capped at 8000 since nothing interesting happens above that for voice

        % Statistics labels - just formatting numbers into text and
        % sticking them onto the labels
        energy_lbl.Text  = sprintf('Energy: %.4f', r.energy);
        maxfreq_lbl.Text = sprintf('Max frequency: %.1f Hz', r.maxFreq);
        mean_lbl.Text    = sprintf('Mean: %.5f', r.meanVal);
        std_lbl.Text     = sprintf('Std deviation: %.5f', r.stdVal);
        var_lbl.Text     = sprintf('Variance: %.6f', r.varVal);
        psd_lbl.Text     = sprintf('Peak PSD: %.6f', r.peakPSD);
    end

%% ================= Layout helpers =================
% these two just exist so I'm not repeating the same lines of code
% 6 times for the plots - basically my own little shortcut functions

    function ax = addPlotCard(row, col, titleStr)
        % makes one "card" - a titled panel with a plot inside it -
        % and places it at the given row/col in the plots grid
        p = uipanel(plotsGrid,'Title',titleStr,'FontWeight','bold','BackgroundColor',colCard);
        p.Layout.Row = row;
        p.Layout.Column = col;
        g = uigridlayout(p,[1 1]);
        g.Padding = [6 6 6 6];
        ax = uiaxes(g);
    end

    function styleAxes(ax, xlab, ylab)
        % makes all plots look the same - same grid style, same font
        % size etc, so it doesn't look like 6 randomly different plots
        xlabel(ax, xlab);
        ylabel(ax, ylab);
        ax.Box = 'on';
        ax.XGrid = 'on';
        ax.YGrid = 'on';
        ax.GridAlpha = 0.15;   % light grid, don't want it too distracting
        ax.FontSize = 10;
        ax.Toolbar.Visible = 'on';   % lets you zoom/pan on the plots by hovering over them
        enableDefaultInteractivity(ax);
    end

end