(function () {
  "use strict";

  const stage = window.STAGE;
  if (!stage) {
    throw new Error("STAGE data is required before stage_flow.js.");
  }

  const stageTitle = document.getElementById("stageTitle");
  const stageHeadline = document.getElementById("stageHeadline");
  const topActions = document.getElementById("topActions");
  const focusLabel = document.getElementById("focusLabel");
  const focusSummary = document.getElementById("focusSummary");
  const focusList = document.getElementById("focusList");
  const stepList = document.getElementById("stepList");
  const board = document.getElementById("board");
  const nodesRoot = document.getElementById("nodes");
  const wireLayer = document.getElementById("wireLayer");
  const payloadRow = document.getElementById("payloadRow");
  const packet = document.getElementById("packet");
  const detailTitle = document.getElementById("detailTitle");
  const detailBody = document.getElementById("detailBody");
  const snippetName = document.getElementById("snippetName");
  const codeBlock = document.getElementById("codeBlock");

  let wireGeometry = new Map();
  let currentStep = 0;
  let stepPreviousButton;
  let stepNextButton;
  let stepIndicator;

  function toneColor(tone) {
    const colors = {
      violet: "#a894ff",
      amber: "#f0bf61",
      blue: "#5aa7ff",
      rose: "#ff7594",
      cyan: "#69dce9",
      green: "#39c88f",
      teal: "#43d0bd",
      slate: "#8fa3b8"
    };
    return colors[tone] || colors.slate;
  }

  function renderHeader() {
    document.title = stage.title + " Flow Demo";
    stageTitle.textContent = stage.title + " Flow Demo";
    stageHeadline.textContent = stage.headline;

    const pill = document.createElement("span");
    pill.className = "pill";
    pill.textContent = stage.title;
    topActions.appendChild(pill);

    stage.navLinks.forEach(function (item) {
      const link = document.createElement("a");
      link.className = "demo-link";
      link.href = item.href;
      link.textContent = item.label;
      topActions.appendChild(link);
    });
  }

  function renderFocus() {
    focusLabel.textContent = stage.focusLabel;
    focusSummary.textContent = stage.focusSummary;
    stage.focus.forEach(function (text) {
      const item = document.createElement("div");
      item.textContent = text;
      focusList.appendChild(item);
    });
  }

  function renderPayload() {
    const label = document.createElement("span");
    label.className = "payload-label";
    label.textContent = "payload";
    payloadRow.appendChild(label);

    stage.payload.forEach(function (value) {
      const byte = document.createElement("span");
      byte.className = "byte";
      byte.textContent = value;
      payloadRow.appendChild(byte);
    });
  }

  function renderNodes() {
    stage.nodes.forEach(function (nodeData) {
      const node = document.createElement("div");
      node.className = "node";
      node.id = "node-" + nodeData.id;
      node.dataset.node = nodeData.id;
      node.style.left = nodeData.x + "%";
      node.style.top = nodeData.y + "%";
      node.style.width = nodeData.w + "%";
      node.style.height = nodeData.h + "%";
      node.style.setProperty("--tone", toneColor(nodeData.tone));

      const title = document.createElement("div");
      title.className = "node-title";

      const dot = document.createElement("span");
      dot.className = "dot";

      const titleText = document.createElement("span");
      titleText.textContent = nodeData.title;

      const body = document.createElement("div");
      body.className = "node-text";
      body.textContent = nodeData.text;

      title.append(dot, titleText);
      node.append(title, body);
      nodesRoot.appendChild(node);
    });
  }

  function renderSteps() {
    stage.steps.forEach(function (step, index) {
      const button = document.createElement("button");
      button.className = "step-btn";
      button.type = "button";
      button.dataset.step = String(index);
      button.textContent = (index + 1) + ". " + step.title;
      button.addEventListener("click", function () {
        setStep(index);
      });
      stepList.appendChild(button);
    });

    const navigation = document.createElement("nav");
    navigation.className = "step-nav";
    navigation.setAttribute("aria-label", "Flow Step 이동");

    stepPreviousButton = document.createElement("button");
    stepPreviousButton.className = "step-nav-btn";
    stepPreviousButton.type = "button";
    stepPreviousButton.setAttribute("aria-label", "이전 Flow Step");
    stepPreviousButton.textContent = "←";
    stepPreviousButton.addEventListener("click", function () {
      setStep(currentStep - 1);
    });

    stepIndicator = document.createElement("span");
    stepIndicator.className = "step-indicator";
    stepIndicator.setAttribute("aria-live", "polite");

    stepNextButton = document.createElement("button");
    stepNextButton.className = "step-nav-btn";
    stepNextButton.type = "button";
    stepNextButton.setAttribute("aria-label", "다음 Flow Step");
    stepNextButton.textContent = "→";
    stepNextButton.addEventListener("click", function () {
      setStep(currentStep + 1);
    });

    navigation.append(stepPreviousButton, stepIndicator, stepNextButton);
    stepList.insertAdjacentElement("afterend", navigation);
  }

  function updateStepNavigation() {
    stepIndicator.textContent = (currentStep + 1) + " / " + stage.steps.length;
    stepPreviousButton.disabled = currentStep === 0;
    stepNextButton.disabled = currentStep === stage.steps.length - 1;
  }

  function edgePoint(fromRect, toRect, boardRect) {
    const fromX = fromRect.left + fromRect.width / 2;
    const fromY = fromRect.top + fromRect.height / 2;
    const toX = toRect.left + toRect.width / 2;
    const toY = toRect.top + toRect.height / 2;
    const deltaX = toX - fromX;
    const deltaY = toY - fromY;
    let x;
    let y;

    if (Math.abs(deltaX / Math.max(fromRect.width, 1)) > Math.abs(deltaY / Math.max(fromRect.height, 1))) {
      x = deltaX >= 0 ? fromRect.right : fromRect.left;
      y = fromY + deltaY * (Math.abs(x - fromX) / Math.max(Math.abs(deltaX), .001));
    } else {
      y = deltaY >= 0 ? fromRect.bottom : fromRect.top;
      x = fromX + deltaX * (Math.abs(y - fromY) / Math.max(Math.abs(deltaY), .001));
    }

    return { x: x - boardRect.left, y: y - boardRect.top };
  }

  function arrowPoints(x1, y1, x2, y2) {
    const angle = Math.atan2(y2 - y1, x2 - x1);
    const size = 9;
    const spread = Math.PI / 7;
    const first = angle + Math.PI - spread;
    const second = angle + Math.PI + spread;
    return [
      [x2 + Math.cos(first) * size, y2 + Math.sin(first) * size],
      [x2, y2],
      [x2 + Math.cos(second) * size, y2 + Math.sin(second) * size]
    ];
  }

  function drawWires() {
    const boardRect = board.getBoundingClientRect();
    wireLayer.setAttribute("viewBox", "0 0 " + boardRect.width + " " + boardRect.height);
    wireLayer.replaceChildren();
    wireGeometry = new Map();

    stage.wires.forEach(function (wireData) {
      const fromElement = document.getElementById("node-" + wireData.from);
      const toElement = document.getElementById("node-" + wireData.to);
      if (!fromElement || !toElement) return;

      const first = edgePoint(fromElement.getBoundingClientRect(), toElement.getBoundingClientRect(), boardRect);
      const second = edgePoint(toElement.getBoundingClientRect(), fromElement.getBoundingClientRect(), boardRect);
      const points = arrowPoints(first.x, first.y, second.x, second.y);
      const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
      const head = document.createElementNS("http://www.w3.org/2000/svg", "polyline");

      group.setAttribute("class", "wire-group");
      group.dataset.wire = wireData.id;
      line.setAttribute("class", "wire");
      line.setAttribute("x1", first.x);
      line.setAttribute("y1", first.y);
      line.setAttribute("x2", second.x);
      line.setAttribute("y2", second.y);
      head.setAttribute("class", "arrow-head");
      head.setAttribute("points", points.map(function (point) {
        return point[0] + "," + point[1];
      }).join(" "));

      group.append(line, head);
      wireLayer.appendChild(group);
      wireGeometry.set(wireData.id, { x1: first.x, y1: first.y, x2: second.x, y2: second.y });
    });

    placePacket(stage.steps[currentStep]);
  }

  function placePacket(step) {
    if (!step || !step.packetWire || !wireGeometry.has(step.packetWire)) {
      packet.style.display = "none";
      return;
    }

    const geometry = wireGeometry.get(step.packetWire);
    const position = .54;
    packet.textContent = step.packet || "tx";
    packet.style.left = (geometry.x1 + (geometry.x2 - geometry.x1) * position) + "px";
    packet.style.top = (geometry.y1 + (geometry.y2 - geometry.y1) * position) + "px";
    packet.style.display = "flex";
  }

  function setStep(index) {
    currentStep = Math.max(0, Math.min(stage.steps.length - 1, index));
    const step = stage.steps[currentStep];

    document.querySelectorAll(".step-btn").forEach(function (button) {
      const isActive = Number(button.dataset.step) === currentStep;
      button.classList.toggle("active", isActive);
      if (isActive) {
        button.setAttribute("aria-current", "step");
      } else {
        button.removeAttribute("aria-current");
      }
    });
    document.querySelectorAll(".node").forEach(function (node) {
      node.classList.toggle("active", step.activeNodes.includes(node.dataset.node));
    });
    document.querySelectorAll(".wire-group").forEach(function (wire) {
      wire.classList.toggle("active", step.activeWires.includes(wire.dataset.wire));
    });

    detailTitle.textContent = step.title;
    detailBody.textContent = step.body;
    codeBlock.textContent = step.code;
    placePacket(step);
    updateStepNavigation();
  }

  renderHeader();
  renderFocus();
  renderPayload();
  renderNodes();
  renderSteps();
  snippetName.textContent = stage.snippet;

  requestAnimationFrame(function () {
    drawWires();
    setStep(0);
  });

  window.addEventListener("resize", function () {
    drawWires();
    setStep(currentStep);
  });
}());
