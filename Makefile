# ===========================================
# Require .env file
# ===========================================
ifeq (,$(wildcard .env))
$(error .env file not found! Please create one in the project root before running Make.)
endif

include .env
export





# ===========================================
# Variable Definition
# ===========================================
ifeq ($(OS),Windows_NT)
	UNAME_S := Windows
	ACTIVATE_PATH := $(VENV_DIR)/Scripts/activate
	PYTHON := python
else
	UNAME_S := $(shell uname -s)
	ACTIVATE_PATH := $(VENV_DIR)/bin/activate
	PYTHON := python3
endif





# ===========================================
# Default Target - Help Menu
# ===========================================
.PHONY: help

help:
	@echo ""
	@echo "==========================================="
	@echo "          Available Make Commands"
	@echo "==========================================="
	@echo ""
	@echo "Virtual Environment:"
	@echo "  make venv-create     : Create virtual environment if missing"
	@echo "  make venv-install    : Install dependencies from requirements.txt"
	@echo "  make venv-ensure     : Ensure venv exists (OS-aware)"
	@echo "  make venv-shell      : Activate the virtual environment shell"
	@echo ""
	@echo "General:"
	@echo "  make help            : Show this help menu"
	@echo ""
	@echo "==========================================="
	@echo ""





# ===========================================
# VENV Make Commands
# ===========================================

.PHONY: venv-create venv-install venv-ensure venv-shell

# -----------------------------------
# Create venv if missing
# -----------------------------------
ifeq ($(wildcard $(VENV_DIR)),)
venv-create:
	@echo Creating virtual environment...
	$(PYTHON) -m venv $(VENV_DIR)
else
venv-create:
	@echo Virtual environment already exists.
endif

# -----------------------------------
# Install dependencies if requirements.txt exists
# -----------------------------------
ifeq ($(wildcard $(REQ_FILE)),)
venv-install:
	@echo ERROR: requirements.txt not found in API directory. && exit 1
else
ifeq ($(OS),Windows_NT)
venv-install: venv-create
	@echo "Activating virtual environment and installing dependencies..."
	@cmd /C "( \
		call $(VENV_DIR)\Scripts\activate && \
		$(PYTHON) -m pip install -r $(REQ_FILE) \
	)"
else
venv-install: venv-create
	@echo "Activating virtual environment and installing dependencies..."
	@bash -c "source $(VENV_DIR)/bin/activate && \
		$(PYTHON) -m pip install --upgrade pip && \
		$(PYTHON) -m pip install -r $(REQ_FILE)"
endif
endif

# -------------------------------------------
# Ensure venv exists (cross-platform)
# -------------------------------------------
ifeq ($(wildcard $(ACTIVATE_PATH)),)
venv-ensure:
ifeq ($(OS),Windows_NT)
	@echo "Virtual environment not found. Creating and installing dependencies..."
	@$(MAKE) install
else
	@echo "Virtual environment not found. Creating and installing dependencies..."
	@$(MAKE) install
endif
else
venv-ensure:
	@echo "Found virtual environment."
endif


# -------------------------------------------
# VENV Shell Command
# -------------------------------------------
ifeq ($(OS),Windows_NT)
venv-shell: venv-ensure
	@echo "Activating virtual environment shell..."
	@cmd /C "( call $(VENV_DIR)\Scripts\activate && cmd )"
else
venv-shell: venv-ensure
	@echo "Activating virtual environment shell..."
	@bash -c "source $(VENV_DIR)/bin/activate && exec bash"
endif




