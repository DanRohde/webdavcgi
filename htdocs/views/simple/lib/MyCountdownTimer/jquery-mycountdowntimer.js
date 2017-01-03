/*********************************************************************
(C) ZE CMS, Humboldt-Universitaet zu Berlin
Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
**********************************************************************
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
**********************************************************************/
(function ( $ ) {


$.fn.MyCountdownTimer = function(option, timeout) {
	var anchor = this;
	var timername = "mycountdowntimer";
	var timeoutname = "mycountdowntimer-timeout";
	var eventprefix = "mycountdowntimer-";
	
	switch (option) {
	case "start":
			startAutoRefreshTimer(timeout);
			break;
	case "toggle":
			toggleAutoRefreshTimer();
			break;
	case "stop":
			stopAutoRefreshTimer();
			break;
	}
	function stopAutoRefreshTimer() {
		if (anchor.data(timeoutname)) {
			window.clearInterval(anchor.data(timername));
			anchor.removeData(timername);
			anchor.trigger(eventprefix+"stopped", { timeout: anchor.data(timeoutname) });
			anchor.removeData(timeoutname);
		}
	}
	function toggleAutoRefreshTimer() {
		if (anchor.data(timername)) {
			window.clearInterval(anchor.data(timername));
			anchor.removeData(timername);
			anchor.trigger(eventprefix+"paused", { timeout: anchor.data(timeoutname) } );
		} else {
			startAutoRefreshTimer(anchor.data(timeoutname));
		}
	}
	function startAutoRefreshTimer(t) {
		stopAutoRefreshTimer();
		anchor.data(timeoutname, t);
		anchor.data(timername, window.setInterval(function() {
			var ct = anchor.data(timeoutname) - 1;
			anchor.data(timeoutname, ct );
			anchor.trigger(eventprefix+"elapsed", { timeout: ct });
			if (ct == 0) {
				anchor.trigger(eventprefix+"lapsed", { timeout: 0 });
				stopAutoRefreshTimer();
			}
		}, 1000));
		anchor.trigger(eventprefix+"started", { timeout: t});
	}
	return this;
}
	
}( jQuery ));