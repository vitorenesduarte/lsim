source("util.R")
source("generic.R")

TO_KEEP <- "'(110|220|230|350|460|470|480|490)'"

# draw!
main <- function() {
  output_file <- "gset_gcounter.png"

  clusters <- c(
    "ls -d processed/* | grep gset~tree~15",
    "ls -d processed/* | grep gcounter~tree~15",
    "ls -d processed/* | grep gset~partialmesh~15",
    "ls -d processed/* | grep gcounter~partialmesh~15"
  )
  clusters <- map(clusters, function(c) {
      paste(c, " | grep -E ", TO_KEEP, sep="")
  })
  titles <- c(
    "GSet - Tree",
    "GCounter - Tree",
    "GSet - Mesh",
    "GCounter - Mesh"
  )
  labels <- c(
    "State-based",
    "Scuttlebutt",
    "Scuttlebutt-GC",
    "Op-based",
    "Delta-based",
    "Delta-based BP",
    "Delta-based RR",
    "Delta-based BP+RR"
  )

  # avoid scientific notation
  options(scipen=999)

  # open device
  png(filename=output_file, width=800, height=650, res=130)

  # change outer margins
  op <- par(
    oma=c(3.5,2,0,0),   # room for the legend
    mfrow=c(2,2),      # 2x4 matrix
    mar=c(2.5,2,2,1) # spacing between plots
  )

  # style stuff
  colors <- c(
    "snow4",
    "darkgoldenrod",
    "steelblue4",
    "yellow3",
    "springgreen4",
    "darkorange1",
    "red4",
    "gray22"
  )
  angles <- c(0, 135, 45, 135, 45, 135, 45, 135)
  densities <- c(0, 15, 15, 22, 30, 30, 45, 45)

  for(i in 1:length(clusters)) {
    files <- system(clusters[i], intern=TRUE)

    # skip if no file
    if(length(files) == 0) next

    # keys
    key <- "transmission"

    # data
    title <- titles[i]
    lines <- map(files, function(f) { sum(json(c(f))[[key]]) })

    # metadata info
    metadata_ratio <- map(
      files,
      function(f) {
        j <- json(c(f))
        r <- sum(j[["transmission_metadata"]]) / sum(j[["transmission"]])
        round(r, 3) * 100
      }
    )
    print(metadata_ratio)

    # (wrto rr)
    if(length(lines) == length(labels)) {
      rr_index <- length(labels)
      rr <- lines[[rr_index]]
      lines <- map(lines, function(v) { v / rr })

      # plot lines
      y_min <- 0
      plot_bars(title, lines, y_min, colors, angles, densities)
    }
  }

  # axis labels
  y_axis_label("Transmission ratio wrto BP+RR")

  par(op) # Leave the last plot
  op <- par(usr=c(0,1,0,1), # Reset the coordinates
            xpd=NA)         # Allow plotting outside the plot region

  # legend
  legend(
    0.1, # x
    -.02, # y 
    cex=1,
    legend=labels,
    angle=angles,
    density=densities,
    fill=colors,
    ncol=2,
    box.col=NA # remove box
  )

  # close device
  dev.off()
}

main()
warnings()
