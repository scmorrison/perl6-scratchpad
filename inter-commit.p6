# Refactor of Jonathan Worthington's inter-commit 
# reactive Perl 6 example to work with the new
# Supply / Supplier implementation:
# https://github.com/rakudo/rakudo/commit/a8231f14b2d5400e0653aac453496e00318142c5

use v6;

class InterCommitWatcher {
    has $supplier;
    has $.log;

    submethod BUILD(:$base) {
        $supplier = Supplier.new;
        $!log = $supplier.Supply;
        self!watch_HEAD();
        self!watch_dir($base);
    }

    method !watch_HEAD() {
        IO::Notification.watch-path('.git/logs/HEAD').act({
            for dir('.inter-commit') {
                unlink($_);
            }
            $supplier.emit("HEAD moved; cleared backups");
        });
    }

    method !watch_dir($dir) {
        IO::Notification.watch-path($dir)\
            .unique(:as(*.path), :expires(1))\
            .map(*.path)\
            .grep(* ne '.inter-commit')\
            .grep(* ne '.git')\
            .act(-> $backup {
                ++state $change_id;
                spurt '.inter-commit/index', :append,
                    "$change_id $backup\n";
                copy $backup, ".inter-commit/$change_id";
                $supplier.emit("Backed up $backup");
                CATCH {
                    default {
                        $supplier.emit("ERROR: could not back up $backup: $_");
                    }
                }
            });
    }
}

multi sub MAIN('watch') {
    unless '.git/HEAD'.IO.e {
        note "Can only use inter-commit in a Git repository";
        exit(1);
    }

    mkdir '.inter-commit';

    my $icw = InterCommitWatcher.new(base => '.');
    $icw.log.tap(&say);
    sleep;
}

multi sub MAIN('list') {
    try print slurp '.inter-commit/index';
}

multi sub MAIN('show', Int $entry) {
    print slurp '.inter-commit/' ~ $entry;
    CATCH {
        default {
            note "No such entry";
            exit 1;
        }
    }
}
