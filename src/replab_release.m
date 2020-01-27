function replab_release
% replab_release Release the current develop branch contents as a stable release
%
% This runs the release process to send the current ``develop``
% branch snapshot to the branch ``master``, taking care of version numbers in the process.
%
% This script works fully offline, interactions with the remote repository are done manually
% by the user.
%
% There are two types of version numbers in RepLAB:
%
% * Version numbers ending in ``-SNAP`` are snapshot version numbers which are not
%   supposed to be stable: that means different versions of the RepLAB codebase can
%   have the same snapshot number.
% * Version numbers **not** ending in ``-SNAP`` are stable version numbers, which are
%   in one to one correspondence with a version of the codebase. It may correspond at
%   most to two commits: the stable commit on the ``develop`` branch, and the merge commit
%   of it on ``master``.
%
% The master branch has only strictly increasing, stable version numbers. The develop
% branch has snapshot version numbers, except during the release process when we "stabilize"
% the version number for one commit.
%
% The release process is as follows.
%
% 0. (Outside of the script) The user must run ``git fetch origin master develop``.
%
% 1. We verify that the repository does not have uncommited changes.
%
% 2. We verify that both the ``develop`` and ``master`` branches are in sync with
%    the ``origin`` remote. If not we abort.
%
% 3. We ask the user to confirm the version number of the stable release (by default,
%    the develop ``-SNAP`` version with the ``-SNAP`` suffix removed), and the number
%    of the next develop version (by default, the current version number with the
%    minor release number incremented, and the ``-SNAP`` suffix added).
%
% 4. We checkout the develop branch.
%
% 5. We set the version number to the stable number.
%
% 6. We run the `replab_generate` script with the ``sphinx`` argument.
%
% 7. We run the `replab_runtests` script. We abort in case of errors.
%
% 8. We run the `replab_checkhelp` script.
%
% 9. We commit on the develop branch.
%
% 10. We checkout the master branch, merge the develop branch by fast-forward.
%
% 11. We tag the master HEAD with a version tag of the form ``vMAJOR.MINOR.PATH``, as in
%     ``v0.5.0``, which is the format that GitHub recognizes for releases.
%
% 12. We checkout the develop branch, set the version number to the next snapshot number,
%     clear autogenerated code/docs and commit.
%
% 13. We output the command that the user should run to push the changes to the remote.
%     In particular, it involves pushing both the master and develop branches, and the
%     release tag.

    assert(exist('replab_version.txt') == 2, 'The current directory must be the RepLAB root folder.');
    [status, cmdout] = system('git rev-parse --abbrev-ref HEAD');
    assert(isequal(strtrim(cmdout), 'develop'), 'The current repository must be on the develop branch to continue.');
    assert(~isempty(getenv('VIRTUAL_ENV')), 'The Python virtual environment must be setup');

    input('Step 0: Press ENTER to confirm that you ran "git fetch origin develop master"');

    disp(' ');
    disp('Step 1: Verifying that the current working tree and index are clean');
    [status, cmdout] = system('git diff --exit-code');
    assert(status == 0, 'The repository has local unstaged changes. Verify you followed the installation instructions on the website.');
    [status, cmdout] = system('git diff --cached --exit-code');
    assert(status == 0, 'The repository has staged but uncommitted changes. Verify you followed the installation instructions on the website.');

    disp(' ');
    disp('Step 2: Verifying that master and develop branches are in sync with remote origin.');
    [status, masterRef] = system('git rev-parse master');
    assert(status == 0, 'Git command failed');
    [status, originMasterRef] = system('git rev-parse origin/master');
    assert(status == 0, 'Git command failed');
    [status, developRef] = system('git rev-parse develop');
    assert(status == 0, 'Git command failed');
    [status, originDevelopRef] = system('git rev-parse origin/develop');
    assert(status == 0, 'Git command failed');
    assert(isequal(masterRef, originMasterRef), 'Please synchronize master with origin/master.');
    assert(isequal(developRef, originDevelopRef), 'Please synchronize develop with origin/develop.');

    disp(' ');
    disp('Step 3: New version numbers');
    currentVersion = replab_Version.current;
    assert(currentVersion.snapshot, 'Current develop version must be a snapshot');
    releaseVersion = currentVersion.asRelease.prompt('Release version');
    assert(~releaseVersion.snapshot, 'Updated release version cannot be a snapshot');
    newDevelopVersion = releaseVersion.incrementedPatch.asSnapshot.prompt('Develop version').asSnapshot;

    disp(' ');
    disp('Step 4: Checkout develop branch');
    status = system('git checkout develop');
    assert(status == 0, 'Git command failed');

    disp(' ');
    disp('Step 5: Set version number to stable release number');
    releaseVersion.updateVersionFile;

    disp(' ');
    disp('Step 6: Run "replab_generate sphinx"');
    replab_generate('sphinx');

    disp(' ');
    disp('Step 7: Run "replab_runtests"');
    assert(replab_runtests, 'Tests failed');

    disp(' ');
    disp('Step 8: Run "replab_checkhelp"');
    assert(replab_checkhelp, 'Help check failed');

    disp(' ');
    disp('Step 9: Commit the stable release on the develop branch');
    status = system('git add -A');
    assert(status == 0, 'Git command failed');
    status = system(sprintf('git commit -m "Version %s"', releaseVersion.toText));
    assert(status == 0, 'Git command failed');

    disp(' ');
    disp('Step 10: Merge the stable release from the develop branch unto the master branch');
    status = system('git checkout master');
    assert(status == 0, 'Git command failed');
    status = system('git merge develop');
    assert(status == 0, 'Git command failed');

    disp(' ');
    disp('Step 11: Tag the stable release');
    status = system(sprintf('git tag %s', releaseVersion.tag));
    assert(status == 0, 'Git command failed');

    disp(' ');
    disp('Step 12: Checkout the develop branch, set the version number to the next snapshot, clear autogenerated code/doc');
    status = system('git checkout develop');
    assert(status == 0, 'Git command failed');
    replab_generate('clear');
    newDevelopVersion.updateVersionFile;
    status = system('git add -A');
    assert(status == 0, 'Git command failed');
    status = system(sprintf('git commit -m "Version %s"', newDevelopVersion.toText));
    assert(status == 0, 'Git command failed');

    disp(' ');
    disp('Step 13: Code to copy/paste');
    disp(' ');
    fprintf('git push origin develop master %s\n', releaseVersion.tag);
end
