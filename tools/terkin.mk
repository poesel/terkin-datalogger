# ================
# Programming port
# ================

# Use MCU_PORT environment variable
$(eval mcu_port     := ${MCU_PORT})

# Fall back to MCU_SERIAL_PORT environment variable
ifeq ($(mcu_port),)
    $(eval mcu_port := ${MCU_SERIAL_PORT})
endif

# Fall back to value from .terkin/floatip
ifneq (,$(wildcard ./.terkin))
    ifeq ($(mcu_port),)
        $(eval mcu_port := $(shell cat '.terkin/floatip'))
    endif
endif

# Set default options for rshell
$(eval mcu_transfer_buffer  := 2048)

# Determine mcu port type
ifneq ($(mcu_port),)
    ifneq (,$(findstring /dev,$(mcu_port)))
        $(eval mcu_port_type := usb)
    else
        $(eval mcu_port_type := ip)
    endif
endif

# Sanity-check effective MCU_PORT
check-mcu-port:
	@if test "${mcu_port}" = ""; then \
		echo "ERROR: MCU port could not be obtained, please set the \"MCU_PORT\" environment variable or populate the \".terkin/floatip\" file."; \
		exit 1; \
	else \
		echo "Device port: ${mcu_port_type} => ${mcu_port}"; \
	fi

# Sanity-check USB MCU_PORT
check-mcu-port-strict:
	@if test "${MCU_PORT}" = ""; then \
		echo "ERROR: MCU port could not be obtained, please set the \"MCU_PORT\" environment variable."; \
		exit 1; \
	fi

## Restart device using the HTTP API
restart-device-http:
	$(eval ip_address := $(mcu_port))

	@# Notify user about the power cycling.
	@$(MAKE) notify status=INFO status_ansi="$(INFO)" message="Restarting device at IP address $(ip_address) using HTTP API."

	@# Send restart command to HTTP API
	@# TODO: If this fails, maybe reset automatically using the serial interface.
	$(eval response := $(shell http --check-status --timeout=2 POST "http://$(ip_address)/restart" 2> /dev/null || (echo "Your command failed with $$?")))

	@# Evaluate response
	@if test "${response}" = "ACK"; then \
		$(MAKE) notify status=OK status_ansi="$(OK)" message="Device restart acknowledged. Please wait some seconds for reboot."; \
	else \
		$(MAKE) notify status=ERROR status_ansi="$(ERROR)" message="Device restart using HTTP API failed. Try using a different method."; \
	fi

	@# TODO: Actually check if device becomes available again before signalling readyness.
	@echo "Ready."


# ===========
# Compilation
# ===========

# Whether to use mpy-cross
$(eval mpy_cross     := ${MPY_CROSS})


# ============
# Terkin Agent
# ============

# About: The Terkin Agent assists with device discovery and maintenance.


## Setup the Terkin Agent.
setup-terkin-agent:
	$(pip3) install --pre --requirement requirements-terkin-agent.txt

## Run the Terkin Agent, e.g. "make terkin-agent action=maintain".
terkin-agent: setup-terkin-agent
	sudo $(python3) -m tools.terkin $(action) $(macs)


## Load the MiniNet module to the device and start a WiFi access point.
provide-wifi: check-mcu-port
	@$(rshell) $(rshell_options) --quiet cp src/lib/mininet.py /flash/lib
	@$(rshell) $(rshell_options) --quiet repl "~ from mininet import MiniNet ~ MiniNet().activate_wifi_ap()"
	@echo

## Load the MiniNet module to the device and start a WiFi STA connection.
connect-wifi: check-mcu-port
	@$(rshell) $(rshell_options) --quiet cp src/lib/mininet.py /flash/lib/mininet_wip.py
	@$(rshell) $(rshell_options) --quiet repl "~ from mininet_wip import MiniNet ~ MiniNet().connect_wifi_sta('$(ssid)', '$(password)')"
	@echo

## Load the MiniNet module to the device and get IP address.
ip-address: check-mcu-port
	@$(rshell) $(rshell_options) --quiet cp src/lib/mininet.py /flash/lib
	@$(rshell) $(rshell_options) --quiet repl "~ from mininet import MiniNet ~ print(MiniNet().get_ip_address()) ~"
	@echo
