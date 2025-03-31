const FlickeringGrid = {
  mounted() {
    this.canvas = this.el.querySelector("canvas");
    this.ctx = this.canvas.getContext("2d");
    this.isInView = false;
    this.animationFrameId = null;
    this.lastTime = 0;
    
    // Get configuration from data attributes
    this.squareSize = parseInt(this.el.dataset.squareSize) || 4;
    this.gridGap = parseInt(this.el.dataset.gridGap) || 6;
    this.flickerChance = parseFloat(this.el.dataset.flickerChance) || 0.3;
    this.color = this.el.dataset.color || "rgb(0, 0, 0)";
    this.maxOpacity = parseFloat(this.el.dataset.maxOpacity) || 0.3;
    
    // Set up observers
    this.setupResizeObserver();
    this.setupIntersectionObserver();
    
    // Initialize canvas
    this.updateCanvasSize();
  },
  
  disconnected() {
    this.cleanup();
  },
  
  destroyed() {
    this.cleanup();
  },
  
  cleanup() {
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
    }
    
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect();
    }
  },
  
  setupResizeObserver() {
    this.resizeObserver = new ResizeObserver(() => {
      this.updateCanvasSize();
    });
    this.resizeObserver.observe(this.el);
  },
  
  setupIntersectionObserver() {
    this.intersectionObserver = new IntersectionObserver(
      ([entry]) => {
        const wasInView = this.isInView;
        this.isInView = entry.isIntersecting;
        
        if (!wasInView && this.isInView) {
          this.startAnimation();
        } else if (wasInView && !this.isInView) {
          this.stopAnimation();
        }
      },
      { threshold: 0 }
    );
    this.intersectionObserver.observe(this.canvas);
  },
  
  updateCanvasSize() {
    const width = this.el.clientWidth;
    const height = this.el.clientHeight;
    const dpr = window.devicePixelRatio || 1;
    
    this.canvas.width = width * dpr;
    this.canvas.height = height * dpr;
    this.canvas.style.width = `${width}px`;
    this.canvas.style.height = `${height}px`;
    
    this.setupGrid(width, height, dpr);
    
    // If already animated, redraw immediately
    if (this.isInView) {
      this.drawGrid();
    }
  },
  
  setupGrid(width, height, dpr) {
    this.dpr = dpr;
    this.cols = Math.floor(width / (this.squareSize + this.gridGap));
    this.rows = Math.floor(height / (this.squareSize + this.gridGap));
    
    // Initialize squares with random opacity
    this.squares = new Float32Array(this.cols * this.rows);
    for (let i = 0; i < this.squares.length; i++) {
      this.squares[i] = Math.random() * this.maxOpacity;
    }
    
    // Convert color to RGBA format for later use
    this.memoizedColor = this.toRGBA(this.color);
  },
  
  toRGBA(color) {
    const canvas = document.createElement("canvas");
    canvas.width = canvas.height = 1;
    const ctx = canvas.getContext("2d");
    if (!ctx) return "rgba(0, 0, 0,";
    
    ctx.fillStyle = color;
    ctx.fillRect(0, 0, 1, 1);
    const [r, g, b] = Array.from(ctx.getImageData(0, 0, 1, 1).data);
    return `rgba(${r}, ${g}, ${b},`;
  },
  
  updateSquares(deltaTime) {
    for (let i = 0; i < this.squares.length; i++) {
      if (Math.random() < this.flickerChance * deltaTime) {
        this.squares[i] = Math.random() * this.maxOpacity;
      }
    }
  },
  
  drawGrid() {
    const { ctx, canvas, cols, rows, squares, dpr, squareSize, gridGap, memoizedColor } = this;
    
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    for (let i = 0; i < cols; i++) {
      for (let j = 0; j < rows; j++) {
        const opacity = squares[i * rows + j];
        ctx.fillStyle = `${memoizedColor}${opacity})`;
        ctx.fillRect(
          i * (squareSize + gridGap) * dpr,
          j * (squareSize + gridGap) * dpr,
          squareSize * dpr,
          squareSize * dpr
        );
      }
    }
  },
  
  startAnimation() {
    this.lastTime = performance.now();
    this.animate(this.lastTime);
  },
  
  stopAnimation() {
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
      this.animationFrameId = null;
    }
  },
  
  animate(time) {
    const deltaTime = (time - this.lastTime) / 1000;
    this.lastTime = time;
    
    this.updateSquares(deltaTime);
    this.drawGrid();
    
    this.animationFrameId = requestAnimationFrame((newTime) => this.animate(newTime));
  }
};

export default FlickeringGrid; 