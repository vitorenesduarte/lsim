source("util.R")
source("generic.R")

TO_KEEP <- "'(220|230|350|490)'"

# draw!
main <- function() {
  output_file <- "metadata.png"

  clusters <- c(
    "ls -d processed/* | grep partialmesh~16",
    "ls -d processed/* | grep partialmesh~32",
    "ls -d processed/* | grep partialmesh~64"
  )
  clusters <- map(clusters, function(c) {
      paste(c, " | grep -E ", TO_KEEP, sep="")
  })
  titles <- c(
    "16 Nodes",
    "32 Nodes",
    "64 Nodes"
  )
  labels <- c(
    "Scuttlebutt",
    "Scuttlebutt-GC",
    "Op-based",
    "Delta-based BP+RR"
  )

  # avoid scientific notation
  options(scipen=999)

  # open device
  png(filename=output_file, width=550, height=350, res=130)

  # change outer margins
  op <- par(
    oma=c(2.5,2,0,0),   # room for the legend
    mfrow=c(1, 3),      # 2x4 matrix
    mar=c(2,2,2,1) # spacing between plots
  )

  # style stuff
  colors <- c(
    "darkgoldenrod",
    "steelblue4",
    "yellow3",
    "gray22"
  )
  angles <- c(135, 45, 135, 135)
  densities <- c(15, 15, 22, 45)

  for(i in 1:length(clusters)) {
    files <- system(clusters[i], intern=TRUE)

    # skip if no file
    if(length(files) == 0) next

    # keys
    key <- "transmission_metadata"

    id_size = 20

    # data
    title <- titles[i]
    lines <- map(files, function(f) {
      entries <- json(c(f))[[key]]
      sum(entries) / length(entries) * id_size / 1000
    })

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

    # plot bars
    y_min <- 0
    plot_bars(title, lines, y_min, colors, angles, densities, 350)
  }

  # axis labels
  y_axis_label("Avg. metadata (MB)")

  par(op) # Leave the last plot
  op <- par(usr=c(0,1,0,1), # Reset the coordinates
            xpd=NA)         # Allow plotting outside the plot region

  # legend
  legend(
    -0.2, # x
    -.6,  # y 
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
