"""Offline installer checks. Run with Python 3 and Bash on Debian (requires dpkg)."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
FIXES = {"bookworm": "8.2.35-1~deb12u1", "trixie": "8.4.27-1~deb13u1"}
SERIES = {"bookworm": "8.2", "trixie": "8.4"}

# All package mutations, configuration writes, and service operations are mocked.
# Version comparisons deliberately use the real Debian dpkg implementation.
MOCKS = r'''
record() { printf '%s\n' "$*" >> "$FIXTURE/events"; }
apt-get() {
    record "apt-get $*"
    if [ "$1" = update ]; then return "${UPDATE_STATUS:-0}"; fi
    [ "${INSTALL_STATUS:-0}" = 0 ] || return "$INSTALL_STATUS"
    touch "$FIXTURE/installed"
}
apt-mark() {
    record "apt-mark $*"
    [ "${HOLD_STATUS:-0}" = 0 ] || return "$HOLD_STATUS"
    cat "$FIXTURE/holds"
}
apt-cache() {
    record "apt-cache $*"
    [ "${POLICY_STATUS:-0}" = 0 ] || return "$POLICY_STATUS"
    local candidate="$TEST_CANDIDATE"
    if [ -f "$FIXTURE/candidates/$2" ]; then candidate=$(cat "$FIXTURE/candidates/$2"); fi
    printf '%s:\n  Installed: (none)\n  Candidate: %s\n' "$2" "$candidate"
}
dpkg-query() {
    [ "${QUERY_STATUS:-0}" = 0 ] || return "$QUERY_STATUS"
    if [ "$#" = 2 ]; then
        cat "$FIXTURE/inventory"
    else
        local version="${TEST_INSTALLED:-$TEST_CANDIDATE}"
        if [ ! -f "$FIXTURE/installed" ]; then version="$PHPSERIES.1-1"; fi
        if [ "$3" = "${TEST_STALE_PACKAGE:-none}" ]; then version="$PHPSERIES.1-1"; fi
        printf '%s %s %s\n' "${TEST_PACKAGE_STATUS:-installed}" "$version" "${TEST_SOURCE:-php$PHPSERIES}"
    fi
}
sed() { record "sed $*"; return "${SED_STATUS:-0}"; }
apache2ctl() { record "apache2ctl $*"; return "${APACHE_CONFIG_STATUS:-0}"; }
systemctl() {
    record "systemctl $*"
    if [ "$1" = show ]; then
        printf '%s\n' "${FPM_ACTIVE_STATE:-active}"
        return "${FPM_QUERY_STATUS:-0}"
    fi
    [ "$2" != "${FAILED_SERVICE:-none}" ]
}
php-fpm8.2() { record "php-fpm8.2 $*"; return "${FPM_CONFIG_STATUS:-0}"; }
php-fpm8.4() { record "php-fpm8.4 $*"; return "${FPM_CONFIG_STATUS:-0}"; }
apt-key() { :; }
'''


class InstallerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not shutil.which("dpkg"):
            raise unittest.SkipTest("Run on Debian: version checks require real dpkg")

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.fixture = Path(self.directory.name)
        (self.fixture / "candidates").mkdir()
        for name in ("inventory", "holds", "events"):
            (self.fixture / name).write_text("")

    def run_shell(self, code, codename="bookworm", script="install.sh", **env):
        environment = dict(os.environ, FIXTURE=str(self.fixture),
                           TEST_CANDIDATE=FIXES[codename], TEST_CODENAME=codename,
                           OSCODENAME=codename)
        environment.update(env)
        return subprocess.run(
            ["bash", "-c", 'source "$1"\n' + MOCKS + "\n" + code, "test", str(ROOT / script)],
            text=True, capture_output=True, env=environment, check=False,
        )

    def events(self):
        return (self.fixture / "events").read_text().splitlines()

    def assert_no_install(self):
        self.assertFalse(any(event.startswith("apt-get install") for event in self.events()))

    def release(self, distro="debian", codename="bookworm"):
        path = self.fixture / "os-release"
        path.write_text('ID={}\nVERSION_CODENAME={}\nPRETTY_NAME="Test OS"\n'.format(distro, codename))
        return path

    def test_os_gates_accept_only_supported_distributions_and_releases(self):
        for script in ("install.sh", "bootstrap.sh"):
            for distro in ("debian", "raspbian", "ubuntu"):
                for release in ("jessie", "stretch", "buster", "bullseye", "bookworm", "trixie", "forky", ""):
                    with self.subTest(script=script, distro=distro, release=release):
                        path = self.release(distro, release)
                        result = self.run_shell('checkos "$TEST_RELEASE"', script=script, TEST_RELEASE=str(path))
                        supported = distro in ("debian", "raspbian") and release in FIXES
                        self.assertEqual(result.returncode == 0, supported, result.stderr)
                        self.assertEqual(self.events(), [])

    def test_entry_points_run_from_file_or_pipe_but_allow_safe_sourcing(self):
        for script in ("install.sh", "bootstrap.sh"):
            with self.subTest(script=script):
                entrypoint = (ROOT / script).read_text().split("### Start the script\n", 1)[1]
                content = "main() { echo main-invoked; }\n" + entrypoint
                path = self.fixture / "entrypoint.sh"
                path.write_text(content)
                for command, stdin, expected in ((["bash", str(path)], None, "main-invoked\n"),
                                                 (["bash"], content, "main-invoked\n"),
                                                 (["bash", "-c", 'source "$1"', "test", str(path)], None, "")):
                    result = subprocess.run(command, input=stdin, text=True, capture_output=True, check=False)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, expected)

    def test_missing_os_file_and_missing_fields_fail_closed(self):
        for script in ("install.sh", "bootstrap.sh"):
            with self.subTest(script=script):
                path = self.fixture / "missing"
                result = self.run_shell('checkos "$TEST_RELEASE"', script=script, TEST_RELEASE=str(path))
                self.assertNotEqual(result.returncode, 0)
                path.write_text("")
                result = self.run_shell('checkos "$TEST_RELEASE"', script=script, TEST_RELEASE=str(path),
                                        ID="debian", VERSION_CODENAME="bookworm")
                self.assertNotEqual(result.returncode, 0)

    def test_both_entry_points_stop_before_mutations_on_unsupported_os(self):
        code = r'''
init() { :; }; checkroot() { :; }; log() { :; }; arguments() { :; }
checkos() { record refused; return 1; }
term() { record unexpected; }; packages() { record unexpected; }
findbrewpi() { record unexpected; }; instructions() { record unexpected; }
main
'''
        for script in ("install.sh", "bootstrap.sh"):
            with self.subTest(script=script):
                (self.fixture / "events").write_text("")
                result = self.run_shell(code, script=script)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.events(), ["refused"])

    def test_supported_releases_refresh_install_and_verify_all_php_packages(self):
        for codename, fixed in FIXES.items():
            with self.subTest(codename=codename):
                (self.fixture / "events").write_text("")
                series = SERIES[codename]
                (self.fixture / "inventory").write_text(
                    "php{0}-opcache installed php{0}\nphp{0}-readline installed php{0}\n".format(series))
                result = self.run_shell("preparephp", codename)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                events = self.events()
                self.assertEqual(events[0], "apt-get update -o APT::Update::Error-Mode=any")
                install = [event for event in events if event.startswith("apt-get install")]
                self.assertEqual(len(install), 1)
                self.assertIn("--no-remove --no-allow-downgrades --assume-yes", install[0])
                for name in ("php{0}", "libapache2-mod-php{0}", "php{0}-cli", "php{0}-cgi",
                             "php{0}-common", "php{0}-mbstring", "php{0}-xml", "php{0}-opcache", "php{0}-readline"):
                    self.assertIn(name.format(series) + "=" + fixed, install[0])

    def test_unsupported_existing_php_branches_refused_before_refresh(self):
        for codename in FIXES:
            for source in ("php5", "php5.6", "php7.4", "php8.1", "php8.3", "php8.5"):
                with self.subTest(codename=codename, source=source):
                    (self.fixture / "inventory").write_text("{}-cli installed {}\n".format(source, source))
                    result = self.run_shell("preparephp", codename)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(self.events(), [])

    def test_removed_php_and_independent_extensions_do_not_block_install(self):
        (self.fixture / "inventory").write_text(
            "php7.4-cli config-files php7.4\nphp8.2-redis installed php-redis\n")
        result = self.run_shell("preparephp")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_refresh_query_policy_hold_and_install_errors_stop_setup(self):
        for option in ("UPDATE_STATUS", "QUERY_STATUS", "POLICY_STATUS", "HOLD_STATUS", "INSTALL_STATUS"):
            with self.subTest(option=option):
                (self.fixture / "events").write_text("")
                result = self.run_shell("preparephp", **{option: "1"})
                self.assertNotEqual(result.returncode, 0)
                if option != "INSTALL_STATUS":
                    self.assert_no_install()

    def test_stale_missing_wrong_branch_and_epoch_masked_candidates_are_refused(self):
        for codename, series in SERIES.items():
            for candidate in ("", "(none)", series + ".34-1" if series == "8.2" else series + ".26-1",
                              "1:" + series + ".1-1", "8.5.12-1", "8.4.27~rc1-1", "invalid"):
                with self.subTest(codename=codename, candidate=candidate):
                    (self.fixture / "events").write_text("")
                    result = self.run_shell("preparephp", codename, TEST_CANDIDATE=candidate)
                    self.assertNotEqual(result.returncode, 0)
                    self.assert_no_install()

    def test_newer_patched_candidates_are_accepted(self):
        for codename, series in SERIES.items():
            with self.subTest(codename=codename):
                result = self.run_shell("preparephp", codename, TEST_CANDIDATE=series + ".99-1")
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_one_stale_extension_blocks_entire_install(self):
        for codename, series in SERIES.items():
            with self.subTest(codename=codename):
                (self.fixture / "events").write_text("")
                (self.fixture / "candidates" / ("php" + series + "-xml")).write_text(series + ".1-1")
                result = self.run_shell("preparephp", codename)
                self.assertNotEqual(result.returncode, 0)
                self.assert_no_install()

    def test_native_and_multiarch_holds_are_respected(self):
        for held in ("php8.2-cli", "php8.2-cli:arm64", "php8.2-cli:armhf"):
            with self.subTest(held=held):
                (self.fixture / "holds").write_text(held + "\n")
                result = self.run_shell("preparephp")
                self.assertNotEqual(result.returncode, 0)
                self.assert_no_install()

    def test_post_install_verification_does_not_trust_apt_success(self):
        for override in ({"TEST_INSTALLED": "8.2.34-1~deb12u1"}, {"TEST_PACKAGE_STATUS": "unpacked"},
                         {"TEST_SOURCE": "php-defaults"}):
            with self.subTest(override=override):
                result = self.run_shell("preparephp", **override)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("not installed with verified patched PHP", result.stderr)

    def test_verification_rescans_for_new_php_branches_and_stale_extensions(self):
        for codename, series in SERIES.items():
            for package, source in (("php8.1-cli", "php8.1"), ("php" + series + "-fpm", "php" + series)):
                with self.subTest(codename=codename, package=package):
                    (self.fixture / "inventory").write_text("")
                    code = '''
preparephp || exit 1
printf '%s installed %s\\n' "$NEW_PACKAGE" "$NEW_SOURCE" >> "$FIXTURE/inventory"
verifyphp
'''
                    result = self.run_shell(code, codename, NEW_PACKAGE=package, NEW_SOURCE=source,
                                            TEST_STALE_PACKAGE=package)
                    self.assertNotEqual(result.returncode, 0)

    def test_verification_without_a_selected_security_minimum_fails(self):
        result = self.run_shell("unset PHPSERIES PHPFIXED; verifyphp")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.events(), [])

    def test_additional_chamber_still_updates_php_before_installation_changes(self):
        code = r'''
init() { :; }; checkroot() { :; }; log() { :; }; arguments() { :; }; term() { :; }
checkos() { OSCODENAME="$TEST_CODENAME"; }
findbrewpi() { SOURCE=existing; }; checkfree() { :; }
checknet() { record unexpected; }
getscriptpath() { record chamber-setup; exit 44; }
main
'''
        result = self.run_shell(code)
        self.assertEqual(result.returncode, 44, result.stdout + result.stderr)
        events = self.events()
        self.assertEqual(events[-1], "chamber-setup")
        self.assertTrue(any(event.startswith("apt-get install") for event in events[:-1]))
        self.assertLess(events.index("systemctl restart apache2.service"), events.index("chamber-setup"))
        self.assertNotIn("unexpected", events)

    def test_bootstrap_refresh_failure_precedes_any_package_install(self):
        result = self.run_shell("packages", script="bootstrap.sh", UPDATE_STATUS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.events(), ["apt-get update -o APT::Update::Error-Mode=any"])

    def test_checked_full_restart_covers_apache_and_existing_fpm(self):
        for codename, series in SERIES.items():
            with self.subTest(codename=codename):
                (self.fixture / "events").write_text("")
                (self.fixture / "inventory").write_text("php{0}-fpm:arm64 installed php{0}\n".format(series))
                result = self.run_shell("preparephp && fixsafari", codename)
                self.assertEqual(result.returncode, 0, result.stderr)
                events = self.events()
                self.assertLess(events.index("apache2ctl configtest"), events.index("systemctl restart apache2.service"))
                self.assertLess(events.index("php-fpm{} --test".format(series)),
                                events.index("systemctl restart apache2.service"))
                self.assertEqual(events[-2:], ["systemctl restart apache2.service",
                                              "systemctl restart php{}-fpm.service".format(series)])

    def test_inactive_fpm_stays_stopped_and_unknown_state_fails(self):
        (self.fixture / "inventory").write_text("php8.2-fpm installed php8.2\n")
        for state in ("inactive", "failed"):
            with self.subTest(state=state):
                (self.fixture / "events").write_text("")
                result = self.run_shell("preparephp && restartphp", FPM_ACTIVE_STATE=state, FPM_CONFIG_STATUS="1")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("php-fpm8.2 --test", self.events())
                self.assertNotIn("systemctl restart php8.2-fpm.service", self.events())
        for override in ({"FPM_ACTIVE_STATE": "unknown"}, {"FPM_ACTIVE_STATE": "activating"},
                         {"FPM_ACTIVE_STATE": "deactivating"}, {"FPM_QUERY_STATUS": "1"}):
            with self.subTest(override=override):
                (self.fixture / "events").write_text("")
                result = self.run_shell("preparephp && restartphp", **override)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("systemctl restart apache2.service", self.events())

    def test_configuration_and_restart_errors_prevent_success(self):
        (self.fixture / "inventory").write_text("php8.2-fpm installed php8.2\n")
        for override in ({"SED_STATUS": "1"}, {"APACHE_CONFIG_STATUS": "1"},
                         {"FAILED_SERVICE": "apache2.service"}, {"FPM_CONFIG_STATUS": "1"},
                         {"FAILED_SERVICE": "php8.2-fpm.service"}):
            with self.subTest(override=override):
                (self.fixture / "events").write_text("")
                result = self.run_shell("preparephp && fixsafari", **override)
                self.assertNotEqual(result.returncode, 0)
                if "APACHE_CONFIG_STATUS" in override:
                    self.assertNotIn("systemctl restart apache2.service", self.events())
                if "FPM_CONFIG_STATUS" in override:
                    self.assertNotIn("systemctl restart apache2.service", self.events())
                    self.assertNotIn("systemctl restart php8.2-fpm.service", self.events())


if __name__ == "__main__":
    unittest.main()
