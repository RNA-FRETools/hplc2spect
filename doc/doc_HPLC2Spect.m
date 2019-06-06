%% HPLC2Spect
% 
% _HPLC2Spect_ is a program to process and analyze 2D-chromatograms
% recorded on a Dionex Ultimate-3000 HPLC system. Chromatograms are generated
% by either a fluorescence or a UV/Vis 3D detector array, giving access to
% the full absorption and excitation/emission spectrum at all retention
% time points.
%
%% Load a 2D-chromatogram
% Go to File->Open File(s) to load a 2D chromatogram (raw output text file
% from Dionex Ultimate-3000). Multiple files can be loaded simultaneously.
% The imported files will display in the dropdown list.
%
%% Evaluate a 2D-chromatogram
% You may either find the peak maximum within a user-defined subrange of
% the chromatogram (*define area*) or manually select a specific point on
% the chromatogram (*manual*).
% 
% To compare retention times and wavelengths you may lock the position of
% the current peak by ticking the *lock position* radiobutton. A solid
% crosshair will mark the location of the selected peak (this selection 
% will remain active, even if you change between chromatograms, until you disable 
% the lock position radiobutton again).
%
% You may also choose to crop the 2D chromatogram (e.g. to get rid of highly 
% intense scattering peaks). For this purpose go to Processing-> *Crop
% Chromatogram* and select a subrange for the spectrum and/or a new time
% interval. Pressing the *export* button will save the cropped chromatogram
% to a selected directory on your hardrive. 
%
% To extract the current spectrum and rentention trace as ASCII files, go
% to Processing-> *Extract Trace/Spectrum*
% 
%
%% Getting Help
%
% The Help Menu directs you to this help page. In case of any further questions
% do not hesitate to contact Fabio Steffen, 34-F-78.
%
%
% _(C) F.Steffen, February 2017_

